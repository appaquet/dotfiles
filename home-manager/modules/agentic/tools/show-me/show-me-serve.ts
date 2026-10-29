/**
 * Show-me HTTP server: one command that serves a directory as a generated index,
 * ordinary static files, or a Markdown reader with a docs tree and shared comments.
 *
 * Every route resolves the request through one access policy beneath the supplied
 * root, and every source byte is read on the request that asks for it.
 */

import { createHash } from "node:crypto";
import { readdir, realpath, stat } from "node:fs/promises";
import path from "node:path";

const RESERVED_SEGMENT = "_show-me";
const RESERVED_PREFIX = `/${RESERVED_SEGMENT}/`;
const READER_ASSET = "docs.html";
const TREE_ASSET = "tree";
const MARKDOWN_EXTENSIONS = [".md", ".markdown"];
const BASE_HEADERS = { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" };

/** Non-hidden directory names that never appear in the index or the docs tree. */
const DENIED_SEGMENTS = new Set(["node_modules", "secrets", "secret", "credentials", "keys"]);

export type AssetMap = Record<string, string>;

export type HandlerOptions = {
  /** Canonical absolute serving root; every route is confined beneath it. */
  root: string;
  /** Logical asset name to absolute file path, served under the reserved namespace. */
  assets: AssetMap;
  /** Opaque, stable identity for this root, used to scope shared feedback drafts. */
  rootId: string;
  /** Display label for the docs tree root. */
  rootLabel: string;
};

export type ServerOptions = {
  root: string;
  assets?: AssetMap;
  rootLabel?: string;
  port?: number;
  hostname?: string;
};

export type ShowMeServer = {
  server: ReturnType<typeof Bun.serve>;
  port: number;
  stop: () => void;
};

/** Create the request handler without starting a listener, for tests and embedding. */
export function createRequestHandler(options: HandlerOptions) {
  const { root, assets, rootId, rootLabel } = options;

  return async function handleRequest(request: Request): Promise<Response> {
    const isHead = request.method === "HEAD";
    if (!isHead && request.method !== "GET") {
      return answer(
        isHead,
        textResponse("Method not allowed\n", 405, { Allow: "GET, HEAD" }),
      );
    }

    const url = new URL(request.url);
    const decoded = decodePathname(url.pathname);
    if (decoded === null) return answer(isHead, textResponse("Bad request\n", 400));

    if (decoded === `/${RESERVED_SEGMENT}` || decoded.startsWith(RESERVED_PREFIX)) {
      return answer(isHead, await handleReserved(decoded, assets, root, rootId, rootLabel));
    }

    return answer(isHead, await handleSource(decoded, url, root, assets));
  };
}

/** Start a listener on the given port (0 picks a free one). */
export async function createShowMeServer(options: ServerOptions): Promise<ShowMeServer> {
  const root = await realpath(options.root);
  await assertReservedNamespaceFree(root);

  const handleRequest = createRequestHandler({
    root,
    assets: options.assets ?? {},
    rootId: createRootId(root),
    rootLabel: options.rootLabel ?? path.basename(root),
  });

  const server = Bun.serve({
    hostname: options.hostname ?? "0.0.0.0",
    port: options.port ?? 0,
    fetch: handleRequest,
  });

  return { server, port: server.port ?? 0, stop: () => server.stop(true) };
}

// --- routes ---

async function handleReserved(
  decoded: string,
  assets: AssetMap,
  root: string,
  rootId: string,
  rootLabel: string,
): Promise<Response> {
  const name = decoded.slice(RESERVED_PREFIX.length);
  if (name === TREE_ASSET) {
    return jsonResponse({ root: { id: rootId, label: rootLabel }, paths: await discoverDocs(root) });
  }
  if (name === "" || name.includes("/")) return textResponse("Not found\n", 404);

  const assetPath = assets[name];
  if (!assetPath) return textResponse("Not found\n", 404);
  return fileResponse(assetPath);
}

async function handleSource(
  decoded: string,
  url: URL,
  root: string,
  assets: AssetMap,
): Promise<Response> {
  const resolved = await resolveSource(root, decoded);
  if (resolved.kind === "error") return textResponse(`${resolved.message}\n`, resolved.status);

  if (resolved.isDirectory) {
    if (!decoded.endsWith("/")) {
      const location = `/${encodePathSegments(resolved.relative)}/${url.search}`;
      return new Response(null, { status: 301, headers: { Location: location, ...BASE_HEADERS } });
    }
    try {
      const entries = await readEntries(root, resolved.absolute, resolved.relative);
      return indexResponse(resolved.relative, entries);
    } catch {
      return textResponse("This directory could not be read\n", 500);
    }
  }

  if (isMarkdown(resolved.absolute)) {
    if (url.searchParams.get("raw") === "1") return fileResponse(resolved.absolute, "text/plain; charset=utf-8");
    const shell = assets[READER_ASSET];
    if (!shell) return textResponse("The Markdown reader is not configured\n", 500);
    return fileResponse(shell, "text/html; charset=utf-8");
  }

  return fileResponse(resolved.absolute);
}

// --- access policy ---

type Resolution =
  | { kind: "ok"; absolute: string; relative: string; isDirectory: boolean }
  | { kind: "error"; status: number; message: string };

/**
 * Confine one decoded request path beneath the root.
 *
 * Hidden and protected segments, escapes, and symlinks whose real target leaves
 * the root are refused before anything is read.
 */
async function resolveSource(root: string, decoded: string): Promise<Resolution> {
  const relative = decoded.replace(/^\/+/, "").replace(/\/+$/, "");
  const segments = relative === "" ? [] : relative.split("/");
  if (segments.includes("..")) return { kind: "error", status: 400, message: "Bad request" };
  if (segments.some(isDeniedSegment)) return { kind: "error", status: 404, message: "Not found" };

  const normalized = path.posix.normalize(relative === "" ? "." : relative);
  if (normalized === ".." || normalized.startsWith("../") || path.isAbsolute(normalized)) {
    return { kind: "error", status: 400, message: "Bad request" };
  }

  const candidate = normalized === "." ? root : path.join(root, normalized);
  if (candidate !== root && !candidate.startsWith(root + path.sep)) {
    return { kind: "error", status: 400, message: "Bad request" };
  }

  let stats;
  try {
    stats = await stat(candidate);
  } catch {
    return { kind: "error", status: 404, message: "Not found" };
  }

  let resolvedPath: string;
  try {
    resolvedPath = await realpath(candidate);
  } catch {
    return { kind: "error", status: 404, message: "Not found" };
  }
  if (!isInsideRoot(root, resolvedPath) || isDeniedRealPath(root, resolvedPath)) {
    return { kind: "error", status: 404, message: "Not found" };
  }

  return {
    kind: "ok",
    absolute: candidate,
    relative: normalized === "." ? "" : normalized,
    isDirectory: stats.isDirectory(),
  };
}

/** True when a directory entry cannot be addressed by a URL at all. */
function isUnaddressableName(name: string): boolean {
  return name.includes("\\");
}

function isDeniedSegment(segment: string): boolean {
  const lower = segment.toLowerCase();
  return lower.startsWith(".") || DENIED_SEGMENTS.has(lower);
}

/** True when a real path beneath the root lands in a hidden or protected tree. */
function isDeniedRealPath(root: string, resolvedPath: string): boolean {
  const relative = path.relative(root, resolvedPath);
  if (relative === "") return false;
  return relative.split(path.sep).some(isDeniedSegment);
}

function isInsideRoot(root: string, candidate: string): boolean {
  return candidate === root || candidate.startsWith(root + path.sep);
}

function decodePathname(pathname: string): string | null {
  let decoded: string;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  // Control characters never name a served path, and the URL parser already treats
  // a backslash as a path separator, so a name containing one is not addressable.
  if (/[\u0000-\u001f\u007f]/.test(decoded) || decoded.includes("\\")) return null;
  return decoded;
}

function isMarkdown(name: string): boolean {
  const extension = path.extname(name).toLowerCase();
  return MARKDOWN_EXTENSIONS.includes(extension);
}

async function assertReservedNamespaceFree(root: string): Promise<void> {
  try {
    await stat(path.join(root, RESERVED_SEGMENT));
  } catch {
    return;
  }
  throw new Error(
    `Cannot serve '${root}': it already contains a '${RESERVED_SEGMENT}' entry, which this server reserves for its own assets and docs tree`,
  );
}

function createRootId(root: string): string {
  return createHash("sha256").update(root).digest("hex").slice(0, 16);
}

// --- directory index ---

type Entry = { name: string; relative: string; isDirectory: boolean };

async function readEntries(root: string, directory: string, relative: string): Promise<Entry[]> {
  const dirents = await readdir(directory, { withFileTypes: true });

  const entries: Entry[] = [];
  for (const dirent of dirents) {
    if (isDeniedSegment(dirent.name) || isUnaddressableName(dirent.name)) continue;
    const childRelative = relative === "" ? dirent.name : `${relative}/${dirent.name}`;
    const isDirectory = await classifyEntry(root, path.join(directory, dirent.name), dirent);
    if (isDirectory === null) continue;
    entries.push({ name: dirent.name, relative: childRelative, isDirectory });
  }

  return entries.sort((left, right) => {
    if (left.isDirectory !== right.isDirectory) return left.isDirectory ? -1 : 1;
    return left.name < right.name ? -1 : left.name > right.name ? 1 : 0;
  });
}

async function classifyEntry(
  root: string,
  absolute: string,
  dirent: { isDirectory: () => boolean; isFile: () => boolean; isSymbolicLink: () => boolean },
): Promise<boolean | null> {
  if (dirent.isDirectory()) return true;
  if (dirent.isFile()) return false;
  if (!dirent.isSymbolicLink()) return null;

  // A symlink is listed only when its real target stays inside the root.
  try {
    const target = await realpath(absolute);
    if (!isInsideRoot(root, target) || isDeniedRealPath(root, target)) return null;
    return (await stat(target)).isDirectory();
  } catch {
    return null;
  }
}

function indexResponse(relative: string, entries: Entry[]): Response {
  const location = relative === "" ? "/" : `/${relative}/`;
  const items = entries.map((entry) => {
    const href = `/${encodePathSegments(entry.relative)}${entry.isDirectory ? "/" : ""}`;
    const label = entry.isDirectory ? `${entry.name}/` : entry.name;
    return `<li><a href="${escapeHtml(href)}">${escapeHtml(label)}</a></li>`;
  });

  if (relative !== "") {
    const parent = relative.split("/").slice(0, -1).join("/");
    items.unshift(`<li><a href="/${encodePathSegments(parent)}${parent === "" ? "" : "/"}">../</a></li>`);
  }

  const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Index of ${escapeHtml(location)}</title>
    <link rel="icon" href="data:," />
    <style>
      :root { color-scheme: light dark; }
      body { margin: 0; padding: 2rem 1.25rem; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; line-height: 1.6; }
      main { width: min(100%, 52rem); margin-inline: auto; }
      h1 { margin: 0 0 1rem; font-size: 1.1rem; font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-weight: 600; }
      ul { margin: 0; padding: 0; list-style: none; }
      li { border-bottom: 1px solid color-mix(in srgb, currentColor 12%, transparent); }
      a { display: block; padding: 0.4rem 0.2rem; color: inherit; text-decoration: none; font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: 0.9rem; }
      a:hover { text-decoration: underline; }
      :focus-visible { outline: 2px solid currentColor; outline-offset: 2px; }
    </style>
  </head>
  <body>
    <main>
      <h1>${escapeHtml(location)}</h1>
      <ul>
        ${items.join("\n        ")}
      </ul>
    </main>
  </body>
</html>
`;

  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8", ...BASE_HEADERS },
  });
}

// --- docs tree ---

async function discoverDocs(root: string): Promise<string[]> {
  const found: string[] = [];
  await walk(root, "");
  return found.sort();

  async function walk(directory: string, relative: string): Promise<void> {
    let dirents;
    try {
      dirents = await readdir(directory, { withFileTypes: true });
    } catch {
      return;
    }

    for (const dirent of dirents) {
      if (isDeniedSegment(dirent.name) || isUnaddressableName(dirent.name)) continue;
      const absolute = path.join(directory, dirent.name);
      const childRelative = relative === "" ? dirent.name : `${relative}/${dirent.name}`;

      if (dirent.isDirectory()) {
        await walk(absolute, childRelative);
        continue;
      }
      if (dirent.isSymbolicLink()) {
        // A linked document is listed; a linked directory is never walked.
        try {
          const target = await realpath(absolute);
          if (!isInsideRoot(root, target) || isDeniedRealPath(root, target)) continue;
          if (!(await stat(target)).isFile()) continue;
        } catch {
          continue;
        }
        if (isMarkdown(dirent.name)) found.push(childRelative);
        continue;
      }
      if (dirent.isFile() && isMarkdown(dirent.name)) found.push(childRelative);
    }
  }
}

// --- responses ---

function answer(isHead: boolean, response: Response): Response {
  if (!isHead) return response;
  return new Response(null, { status: response.status, headers: response.headers });
}

function textResponse(body: string, status: number, headers: Record<string, string> = {}): Response {
  return new Response(body, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8", ...BASE_HEADERS, ...headers },
  });
}

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    headers: { "Content-Type": "application/json; charset=utf-8", ...BASE_HEADERS },
  });
}

function fileResponse(absolute: string, contentType?: string): Response {
  const file = Bun.file(absolute);
  const headers: Record<string, string> = { ...BASE_HEADERS, "Content-Length": String(file.size) };
  if (contentType) headers["Content-Type"] = contentType;
  else if (file.type) headers["Content-Type"] = file.type;
  return new Response(file, { headers });
}

function encodePathSegments(relative: string): string {
  return relative.split("/").map(encodeURIComponent).join("/");
}

function escapeHtml(text: string): string {
  return text.replace(
    /[&<>"']/g,
    (character) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character] ?? character,
  );
}

// --- process entrypoint ---

type CliOptions = { root: string; port: number; assetsDirectory: string | null; label: string | null };

function parseArguments(argv: string[]): CliOptions {
  const values = new Map<string, string>();
  for (let index = 0; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (!flag?.startsWith("--") || value === undefined) {
      throw new Error(`Unexpected arguments. Usage: show-me-serve --root <dir> --port <port> [--assets <dir>] [--label <text>]`);
    }
    values.set(flag.slice(2), value);
  }

  const root = values.get("root");
  const port = values.get("port");
  if (!root || !port) {
    throw new Error("Usage: show-me-serve --root <dir> --port <port> [--assets <dir>] [--label <text>]");
  }
  if (!/^\d+$/.test(port)) throw new Error(`Port must be a number, got '${port}'`);

  return {
    root,
    port: Number(port),
    assetsDirectory: values.get("assets") ?? null,
    label: values.get("label") ?? null,
  };
}

async function loadAssets(directory: string | null): Promise<AssetMap> {
  if (!directory) return {};
  const assets: AssetMap = {};
  for (const dirent of await readdir(directory, { withFileTypes: true })) {
    if (dirent.isFile()) assets[dirent.name] = path.join(directory, dirent.name);
  }
  return assets;
}

if (import.meta.main) {
  try {
    const options = parseArguments(Bun.argv.slice(2));
    const assets = await loadAssets(options.assetsDirectory);
    const started = await createShowMeServer({
      root: options.root,
      assets,
      rootLabel: options.label ?? undefined,
      port: options.port,
    });
    console.log(`show-me server ready on port ${started.port}`);
  } catch (error) {
    console.error(`show-me server failed to start: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
  }
}
