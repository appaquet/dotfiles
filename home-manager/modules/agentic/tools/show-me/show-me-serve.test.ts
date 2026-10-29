import { afterEach, describe, expect, test } from "bun:test";
import { mkdir, mkdtemp, readFile, rename, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

import { createShowMeServer, type AssetMap } from "./show-me-serve.ts";

const READER_SHELL = "<!doctype html><title>reader shell</title>";
const PNG_BYTES = Buffer.from(
  "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c6360000002000100ffff03000006000557bfabd40000000049454e44ae426082",
  "hex",
);

const cleanups: Array<() => Promise<void> | void> = [];

afterEach(async () => {
  while (cleanups.length > 0) await cleanups.pop()?.();
});

async function makeRoot(layout: Record<string, string | Buffer>): Promise<string> {
  const root = await mkdtemp(path.join(tmpdir(), "show-me-root-"));
  cleanups.push(() => rm(root, { recursive: true, force: true }));
  for (const [relative, content] of Object.entries(layout)) {
    const absolute = path.join(root, relative);
    await mkdir(path.dirname(absolute), { recursive: true });
    await writeFile(absolute, content);
  }
  return root;
}

async function makeAssets(): Promise<AssetMap> {
  const directory = await mkdtemp(path.join(tmpdir(), "show-me-assets-"));
  cleanups.push(() => rm(directory, { recursive: true, force: true }));
  await writeFile(path.join(directory, "docs.html"), READER_SHELL);
  await writeFile(path.join(directory, "feedback.js"), "export const mounted = true;\n");
  return {
    "docs.html": path.join(directory, "docs.html"),
    "feedback.js": path.join(directory, "feedback.js"),
  };
}

async function start(root: string, assets: AssetMap = {}) {
  const started = await createShowMeServer({ root, assets, port: 0, hostname: "127.0.0.1" });
  cleanups.push(() => started.stop());
  const origin = `http://127.0.0.1:${started.port}`;
  return {
    port: started.port,
    get: (target: string, init?: RequestInit) => fetch(`${origin}${target}`, init),
  };
}

function hrefs(html: string): string[] {
  return [...html.matchAll(/<a href="([^"]*)"/g)].map((match) => match[1]);
}

const BASE_LAYOUT = {
  "index.html": "<h1>home page</h1>",
  "notes.md": "# Notes\n",
  "assets/app.js": "console.log(1);\n",
  "assets/style.css": "body { margin: 0; }\n",
  "assets/pixel.png": PNG_BYTES,
  "docs/guide.md": "# Guide\n",
  "docs/deep/page.md": "# Page\n",
  "empty.md": "",
  "README.MD": "# Upper\n",
};

describe("directory index", () => {
  test("lists directories then files, even when index.html exists", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    const response = await server.get("/");
    const body = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("text/html");
    expect(hrefs(body)).toEqual(["/assets/", "/docs/", "/README.MD", "/empty.md", "/index.html", "/notes.md"]);
    expect(body).not.toContain("<h1>home page</h1>");
  });

  test("lists a nested directory with a parent link", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    const body = await (await server.get("/docs/")).text();

    expect(hrefs(body)).toEqual(["/", "/docs/deep/", "/docs/guide.md"]);
  });

  test("redirects a directory without a trailing slash and keeps the query", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    const response = await server.get("/docs?sort=name", { redirect: "manual" });

    expect(response.status).toBe(301);
    expect(response.headers.get("location")).toBe("/docs/?sort=name");

    // A leading double slash must not become a protocol-relative Location.
    const doubled = await server.get("//docs", { redirect: "manual" });
    expect(doubled.status).toBe(301);
    expect(doubled.headers.get("location")).toBe("/docs/");
  });

  test("serves index.html as a plain file when asked for it explicitly", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    const response = await server.get("/index.html");

    expect(response.status).toBe(200);
    expect(await response.text()).toBe("<h1>home page</h1>");
  });
});

describe("static files", () => {
  test("return exact bytes with their own content types", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    const script = await server.get("/assets/app.js");
    expect(script.status).toBe(200);
    expect(script.headers.get("content-type")).toContain("javascript");
    expect(await script.text()).toBe("console.log(1);\n");

    const style = await server.get("/assets/style.css");
    expect(style.headers.get("content-type")).toContain("text/css");
    expect(await style.text()).toBe("body { margin: 0; }\n");

    const image = await server.get("/assets/pixel.png");
    expect(image.headers.get("content-type")).toBe("image/png");
    expect(Buffer.from(await image.arrayBuffer())).toEqual(PNG_BYTES);
  });

  test("never wrap an ordinary file in the reader", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root, await makeAssets());

    const body = await (await server.get("/index.html")).text();

    expect(body).not.toContain("reader shell");
  });

  test("answer HEAD with the GET status and headers and no body", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root, await makeAssets());

    const index = await server.get("/", { method: "HEAD" });
    expect(index.status).toBe(200);
    expect(index.headers.get("content-type")).toContain("text/html");
    expect(await index.text()).toBe("");

    const markdown = await server.get("/notes.md", { method: "HEAD" });
    expect(markdown.status).toBe(200);
    expect(markdown.headers.get("content-type")).toContain("text/html");
    expect(await markdown.text()).toBe("");

    const get = await server.get("/notes.md");
    expect(markdown.headers.get("content-length")).toBe(get.headers.get("content-length"));

    expect((await server.get("/missing.md", { method: "HEAD" })).status).toBe(404);
  });

  test("refuse mutation methods without touching the root", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    for (const method of ["POST", "PUT", "PATCH", "DELETE"]) {
      const response = await server.get("/notes.md", { method });
      expect(response.status).toBe(405);
      expect(response.headers.get("allow")).toBe("GET, HEAD");
    }

    expect(await readFile(path.join(root, "notes.md"), "utf8")).toBe("# Notes\n");
  });
});

describe("markdown", () => {
  test("return the reader shell at the document's own URL", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root, await makeAssets());

    for (const target of ["/notes.md", "/docs/guide.md", "/README.MD"]) {
      const response = await server.get(target);
      expect(response.status).toBe(200);
      expect(response.headers.get("content-type")).toContain("text/html");
      expect(await response.text()).toBe(READER_SHELL);
    }
  });

  test("return exact live source for raw requests", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root, await makeAssets());

    const response = await server.get("/notes.md?raw=1");

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("text/plain; charset=utf-8");
    expect(await response.text()).toBe("# Notes\n");
  });

  test("serve version B after edits and atomic replacement", async () => {
    const root = await makeRoot({ "notes.md": "# Version A\n" });
    const server = await start(root, await makeAssets());
    const absolute = path.join(root, "notes.md");

    expect(await (await server.get("/notes.md?raw=1")).text()).toBe("# Version A\n");

    await writeFile(absolute, "# Version B\n");
    expect(await (await server.get("/notes.md?raw=1")).text()).toBe("# Version B\n");

    const staging = path.join(root, "notes.staging");
    await writeFile(staging, "# Version C\n");
    await rename(staging, absolute);
    expect(await (await server.get("/notes.md?raw=1")).text()).toBe("# Version C\n");
  });

  test("treat an empty document as present, not missing", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root, await makeAssets());

    const raw = await server.get("/empty.md?raw=1");
    expect(raw.status).toBe(200);
    expect(await raw.text()).toBe("");

    expect((await server.get("/empty.md")).status).toBe(200);
  });

  test("report a missing reader shell instead of returning source", async () => {
    const root = await makeRoot({ "notes.md": "# Notes\n" });
    const server = await start(root);

    const response = await server.get("/notes.md");

    expect(response.status).toBe(500);
    expect(await response.text()).toContain("not configured");
  });

  test("mark reader, source, index, and tree responses as uncached", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root, await makeAssets());

    for (const target of ["/", "/notes.md", "/notes.md?raw=1", "/_show-me/tree"]) {
      expect((await server.get(target)).headers.get("cache-control")).toBe("no-store");
    }
  });
});

describe("docs tree", () => {
  test("return root identity and root-relative markdown paths", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    const body = await (await server.get("/_show-me/tree")).json();

    expect(body.root.id).toMatch(/^[0-9a-f]{16}$/);
    expect(body.root.label).toBe(path.basename(root));
    expect(body.paths).toEqual(["README.MD", "docs/deep/page.md", "docs/guide.md", "empty.md", "notes.md"]);
    expect(JSON.stringify(body)).not.toContain(root);
  });

  test("keep one identity per root across restarts", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const other = await makeRoot({ "a.md": "# A\n" });

    const first = await (await (await start(root)).get("/_show-me/tree")).json();
    const second = await (await (await start(root)).get("/_show-me/tree")).json();
    const elsewhere = await (await (await start(other)).get("/_show-me/tree")).json();

    expect(first.root.id).toBe(second.root.id);
    expect(first.root.id).not.toBe(elsewhere.root.id);
  });

  test("see added and deleted documents without a restart", async () => {
    const root = await makeRoot({ "notes.md": "# Notes\n" });
    const server = await start(root);

    expect((await (await server.get("/_show-me/tree")).json()).paths).toEqual(["notes.md"]);

    await writeFile(path.join(root, "added.md"), "# Added\n");
    expect((await (await server.get("/_show-me/tree")).json()).paths).toEqual(["added.md", "notes.md"]);

    await rm(path.join(root, "notes.md"));
    expect((await (await server.get("/_show-me/tree")).json()).paths).toEqual(["added.md"]);
  });

  test("skip dependency, hidden, and protected trees", async () => {
    const root = await makeRoot({
      "notes.md": "# Notes\n",
      "node_modules/pkg/readme.md": "# Dep\n",
      ".git/COMMIT_EDITMSG": "msg\n",
      "secrets/plan.md": "# Secret\n",
      "guide/visible.md": "# Visible\n",
    });
    const server = await start(root);

    const tree = await (await server.get("/_show-me/tree")).json();
    expect(tree.paths).toEqual(["guide/visible.md", "notes.md"]);

    const index = hrefs(await (await server.get("/")).text());
    expect(index).toEqual(["/guide/", "/notes.md"]);
  });

  test("list a linked document but never walk a linked directory", async () => {
    const outside = await mkdtemp(path.join(tmpdir(), "show-me-outside-"));
    cleanups.push(() => rm(outside, { recursive: true, force: true }));
    await writeFile(path.join(outside, "outside.md"), "# Outside\n");

    const root = await makeRoot({ "notes.md": "# Notes\n" });
    await symlink(path.join(outside, "outside.md"), path.join(root, "outside-link.md"));
    await symlink(outside, path.join(root, "outside-dir"));

    const server = await start(root);
    const tree = await (await server.get("/_show-me/tree")).json();

    expect(tree.paths).toEqual(["notes.md"]);
  });

  test("survive a directory symlink loop", async () => {
    const root = await makeRoot({ "notes.md": "# Notes\n", "docs/guide.md": "# Guide\n" });
    await symlink(path.join(root, "docs"), path.join(root, "docs", "loop"));

    const server = await start(root);
    const tree = await (await server.get("/_show-me/tree")).json();

    expect(tree.paths).toEqual(["docs/guide.md", "notes.md"]);
  });
});

describe("access policy", () => {
  test("refuse traversal and encoded escapes", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root);

    // An encoded slash survives URL normalization, so the raw escape reaches the policy.
    const escaped = await server.get("/..%2f..%2fetc%2fpasswd");
    expect(escaped.status).toBe(400);
    expect(await escaped.text()).toBe("Bad request\n");

    // Dot segments the URL parser already collapses can only resolve inside the root.
    for (const target of ["/%2e%2e/%2e%2e/etc/passwd", "/docs/%2e%2e/%2e%2e/etc/passwd"]) {
      const response = await server.get(target);
      expect(response.status).toBe(404);
      expect(await response.text()).toBe("Not found\n");
    }
  });

  test("refuse protected and dependency paths on direct URLs", async () => {
    const root = await makeRoot({
      ".env": "TOKEN=1\n",
      ".git/config": "[core]\n",
      "node_modules/pkg/index.js": "module.exports = 1;\n",
      "secrets/creds.txt": "hunter2\n",
      "notes.md": "# Notes\n",
    });
    const server = await start(root, await makeAssets());

    for (const target of ["/.env", "/.git/config", "/node_modules/pkg/index.js", "/secrets/creds.txt"]) {
      const response = await server.get(target);
      expect(response.status).toBe(404);
      expect(await response.text()).toBe("Not found\n");
    }
  });

  test("serve an internal file symlink and refuse one leaving the root", async () => {
    const outside = await mkdtemp(path.join(tmpdir(), "show-me-outside-"));
    cleanups.push(() => rm(outside, { recursive: true, force: true }));
    await writeFile(path.join(outside, "secret.md"), "# Secret\n");

    const root = await makeRoot({ "real.md": "# Real\n" });
    await symlink(path.join(root, "real.md"), path.join(root, "alias.md"));
    await symlink(path.join(outside, "secret.md"), path.join(root, "escape.md"));

    const server = await start(root, await makeAssets());

    expect(await (await server.get("/alias.md?raw=1")).text()).toBe("# Real\n");
    expect((await server.get("/escape.md")).status).toBe(404);
    expect((await server.get("/escape.md?raw=1")).status).toBe(404);
    expect(hrefs(await (await server.get("/")).text())).toEqual(["/alias.md", "/real.md"]);
  });

  test("refuse a symlink that resolves into a protected tree", async () => {
    const root = await makeRoot({
      ".git/config": "[core]\n",
      "node_modules/pkg/index.js": "module.exports = 1;\n",
      "notes.md": "# Notes\n",
    });
    await symlink(path.join(root, ".git"), path.join(root, "pub"));
    await symlink(path.join(root, "node_modules", "pkg", "index.js"), path.join(root, "alias.js"));

    const server = await start(root, await makeAssets());

    expect((await server.get("/pub/config")).status).toBe(404);
    expect((await server.get("/alias.js")).status).toBe(404);
    expect(hrefs(await (await server.get("/")).text())).toEqual(["/notes.md"]);

    const tree = await (await server.get("/_show-me/tree")).json();
    expect(tree.paths).toEqual(["notes.md"]);
  });

  test("match protected names regardless of case", async () => {
    const root = await makeRoot({ "SECRETS/plan.md": "# Secret\n", "notes.md": "# Notes\n" });
    const server = await start(root, await makeAssets());

    expect((await server.get("/SECRETS/plan.md")).status).toBe(404);
    expect(hrefs(await (await server.get("/")).text())).toEqual(["/notes.md"]);
  });

  test("keep the reserved namespace out of the filesystem", async () => {
    const root = await makeRoot(BASE_LAYOUT);
    const server = await start(root, await makeAssets());

    for (const target of ["/_show-me/..%2fnotes.md", "/_show-me/unknown.js", "/_show-me/docs.html/extra"]) {
      expect((await server.get(target)).status).toBe(404);
    }

    const asset = await server.get("/_show-me/feedback.js");
    expect(asset.status).toBe(200);
    expect(await asset.text()).toBe("export const mounted = true;\n");
  });

  test("escape index labels and round-trip unusual names", async () => {
    const root = await makeRoot({
      "back\\slash.md": "# Slash\n",
      "a<b>c.md": "# Bold\n",
      "héllo wörld.md": "# Unicode\n",
      "a%b#c.md": "# Odd\n",
    });
    const server = await start(root, await makeAssets());

    const index = await (await server.get("/")).text();
    expect(index).toContain("a&lt;b&gt;c.md");
    expect(index).not.toContain("<b>");

    for (const name of ["héllo wörld.md", "a%b#c.md", "a<b>c.md"]) {
      const response = await server.get(`/${encodeURIComponent(name)}?raw=1`);
      expect(response.status).toBe(200);
      expect((await response.text()).startsWith("# ")).toBe(true);
    }

    const tree = await (await server.get("/_show-me/tree")).json();
    expect(tree.paths).toEqual(["a%b#c.md", "a<b>c.md", "héllo wörld.md"]);

    // A name the URL parser cannot address is never listed, so no dead link appears.
    expect(hrefs(index)).toEqual(["/a%25b%23c.md", "/a%3Cb%3Ec.md", "/h%C3%A9llo%20w%C3%B6rld.md"]);
    expect((await server.get("/back%5Cslash.md?raw=1")).status).toBe(400);
  });

  test("fail without leaking absolute paths or stack traces", async () => {
    const root = await makeRoot({ "notes.md": "# Notes\n" });
    const server = await start(root, await makeAssets());

    const missing = await server.get("/nope.md");
    expect(missing.status).toBe(404);
    expect(await missing.text()).toBe("Not found\n");

    const denied = await server.get("/.hidden/file.md");
    expect(denied.status).toBe(404);
    expect(await denied.text()).not.toContain(root);
  });
});

describe("startup", () => {
  test("refuse a root that already owns the reserved namespace", async () => {
    const root = await makeRoot({ "_show-me/keep.txt": "mine\n" });

    await expect(createShowMeServer({ root, port: 0, hostname: "127.0.0.1" })).rejects.toThrow(
      /already contains a '_show-me' entry/,
    );
  });
});
