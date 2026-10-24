/**
 * Discovers chat models for `models.json` providers marked
 * `discoverModels: true`. The async factory fetches `GET {baseUrl}/models`
 * before startup model selection runs (Pi awaits extension factories), so
 * the discovered catalog exists synchronously at first use.
 *
 * Pi composes extension-registered models above `models.json` but below
 * `models.json` `modelOverrides`, and does not merge provider-level `compat`
 * into extension-provided models. The provider `compat` is therefore baked
 * into every model definition this extension registers, while per-model
 * metadata (context window, output cap, input modalities, thinking map,
 * sampling) stays declarative in `models.json` `modelOverrides`.
 *
 * The catalog persists to `{agentDir}/extensions/model-discovery/cache.json`
 * as the raw discovered ids, keyed by a provider config fingerprint, so
 * startup is cache-first and survives an unreachable endpoint. Models are
 * constructed at registration time from the ids plus the provider's
 * optional `discoverDefaults`, so editing those defaults in `models.json`
 * takes effect at the next startup without a re-fetch.
 * `refreshModels` re-fetches when Pi refreshes (e.g. `/model` opens) and
 * returns the last list when the network is unavailable, never clearing the
 * catalog.
 *
 * Silent by design: no commands, panels, notices, or writes outside the
 * cache file.
 */
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ProviderConfig } from "@earendil-works/pi-coding-agent";

/** Abort the startup fetch this long; hosts off the LAN must not stall startup. */
const STARTUP_FETCH_TIMEOUT_MS = 15_000;

/** Discovered models get these defaults; `modelOverrides` corrects per model. */
const DEFAULT_CONTEXT_WINDOW = 1_048_576;
const DEFAULT_MAX_TOKENS = 65_536;

interface ProviderEntry {
  baseUrl?: string;
  api?: string;
  apiKey?: string;
  headers?: Record<string, string>;
  compat?: Record<string, unknown>;
  discoverModels?: boolean;
  discoverDefaults?: DiscoverDefaults;
}

interface DiscoveredModel {
  id: string;
  name: string;
  input: ("text" | "image")[];
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
  reasoning: boolean;
  contextWindow: number;
  maxTokens: number;
  thinkingLevelMap: Record<string, string>;
  compat: Record<string, unknown>;
}

/**
 * Per-provider defaults for discovered models, settable in `models.json` as
 * `discoverDefaults`. Each provided field merges over the built-in parity
 * default; `modelOverrides` still applies last.
 */
interface DiscoverDefaults {
  contextWindow?: number;
  maxTokens?: number;
  input?: ("text" | "image")[];
  reasoning?: boolean;
  thinkingLevelMap?: Record<string, string>;
}

interface CacheFile {
  version: 1;
  providers: Record<string, { fingerprint: string; ids: string[] }>;
}

type ModelsRefreshContext = Parameters<
  NonNullable<ProviderConfig["refreshModels"]>
>[0];

export default async function (pi: ExtensionAPI): Promise<void> {
  const dir = resolveAgentDir();
  const entries = readProviderEntries(dir);
  const cache = loadCache(cacheFile(dir));

  for (const [providerId, entry] of Object.entries(entries)) {
    if (
      !entry ||
      entry.discoverModels !== true ||
      typeof entry.baseUrl !== "string" ||
      typeof entry.api !== "string"
    ) {
      continue;
    }

    const fingerprint = fingerprintOf(entry);
    const cached = cache.providers[providerId];
    const validIds = (ids: unknown): ids is string[] =>
      Array.isArray(ids) && ids.every((id) => typeof id === "string");
    // The cache holds the raw discovered ids; models are constructed at
    // registration time so discoverDefaults edits apply without a re-fetch.
    let ids: string[] | undefined =
      cached &&
      cached.fingerprint === fingerprint &&
      validIds(cached.ids)
        ? cached.ids
        : undefined;

    // Startup fetch is best effort: on failure fall back to any stale cache.
    if (!ids) {
      try {
        const signal = AbortSignal.timeout(STARTUP_FETCH_TIMEOUT_MS);
        ids = await fetchModelIds(entry, signal);
        persist(cache, cacheFile(dir), providerId, fingerprint, ids);
      } catch {
        ids = cached && validIds(cached.ids) ? cached.ids : undefined;
      }
    }

    const lastModels: DiscoveredModel[] = (ids ?? []).map((id) =>
      toDiscoveredModel(id, entry.compat, entry.discoverDefaults),
    );
    pi.registerProvider(providerId, {
      baseUrl: entry.baseUrl,
      api: entry.api as ProviderConfig["api"],
      ...(lastModels.length > 0
        ? { models: lastModels as ProviderConfig["models"] }
        : {}),
      headers: entry.headers,
      refreshModels: async (context: ModelsRefreshContext) => {
        if (!context.allowNetwork) {
          return lastModels;
        }
        try {
          const fresh = await fetchModelIds(entry, context.signal);
          lastModels.splice(
            0,
            lastModels.length,
            ...fresh.map((id) =>
              toDiscoveredModel(id, entry.compat, entry.discoverDefaults),
            ),
          );
          persist(cache, cacheFile(dir), providerId, fingerprint, fresh);
          return lastModels;
        } catch {
          return lastModels;
        }
      },
    });
  }
}

/** Resolve the agent dir, mirroring Pi's own `PI_CODING_AGENT_DIR` handling. */
function resolveAgentDir(): string {
  const env = process.env.PI_CODING_AGENT_DIR;
  if (env === undefined || env === "") return path.join(os.homedir(), ".pi", "agent");
  if (env === "~") return os.homedir();
  if (env.startsWith("~/")) return path.join(os.homedir(), env.slice(2));
  return env;
}

function modelsFile(dir: string): string {
  return path.join(dir, "models.json");
}

function cacheFile(dir: string): string {
  return path.join(dir, "extensions", "model-discovery", "cache.json");
}

/** `models.json` providers; a missing or malformed file yields no targets. */
function readProviderEntries(dir: string): Record<string, ProviderEntry> {
  try {
    const raw = fs.readFileSync(modelsFile(dir), "utf-8");
    const data = JSON.parse(raw) as { providers?: unknown };
    if (data.providers && typeof data.providers === "object") {
      return data.providers as Record<string, ProviderEntry>;
    }
  } catch {
    // Absent or unparseable models.json: nothing to discover.
  }
  return {};
}

/** Stable identity of the fields a discovery request and its compat depend on. */
function fingerprintOf(entry: ProviderEntry): string {
  return JSON.stringify([
    entry.baseUrl,
    entry.api,
    entry.apiKey,
    entry.headers ?? null,
    entry.compat ?? null,
  ]);
}

function loadCache(file: string): CacheFile {
  try {
    const data = JSON.parse(fs.readFileSync(file, "utf-8")) as Partial<CacheFile>;
    if (data.providers && typeof data.providers === "object") {
      return { version: 1, providers: data.providers };
    }
  } catch {
    // Missing or corrupt cache: start empty.
  }
  return { version: 1, providers: {} };
}

function persist(
  cache: CacheFile,
  file: string,
  providerId: string,
  fingerprint: string,
  ids: string[],
): void {
  try {
    cache.providers[providerId] = { fingerprint, ids };
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, `${JSON.stringify(cache, null, 2)}\n`, "utf-8");
  } catch {
    // Cache is a convenience; a write failure must not break startup.
  }
}

/** Model ids from `GET {baseUrl}/models`; tolerates a bare array body. */
async function fetchModelIds(
  entry: ProviderEntry,
  signal: AbortSignal,
): Promise<string[]> {
  const url = `${entry.baseUrl}/models`;
  const headers: Record<string, string> = { ...(entry.headers ?? {}) };
  if (entry.apiKey) headers.Authorization = `Bearer ${entry.apiKey}`;
  const response = await fetch(url, { headers, signal });
  if (!response.ok) {
    throw new Error(`GET ${url} failed: HTTP ${response.status}`);
  }
  const body = (await response.json()) as
    | { data?: unknown }
    | Array<{ id?: unknown }>;
  const list = Array.isArray(body) ? body : body.data;
  if (!Array.isArray(list)) {
    throw new Error(`GET ${url}: unexpected response shape`);
  }
  return list
    .map((model) => (model && typeof model === "object" ? model.id : undefined))
    .filter((id): id is string => typeof id === "string");
}

/**
 * Discovered models get the conservative defaults, overridden field-by-field
 * by the provider's `discoverDefaults`, plus the provider `compat`.
 */
function toDiscoveredModel(
  id: string,
  providerCompat: Record<string, unknown> | undefined,
  defaults: DiscoverDefaults | undefined,
): DiscoveredModel {
  return {
    id,
    name: id,
    input: defaults?.input ?? ["text", "image"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    reasoning: defaults?.reasoning ?? true,
    contextWindow: defaults?.contextWindow ?? DEFAULT_CONTEXT_WINDOW,
    maxTokens: defaults?.maxTokens ?? DEFAULT_MAX_TOKENS,
    // Surface xhigh/max in /thinking; modelOverrides may narrow per model.
    thinkingLevelMap: defaults?.thinkingLevelMap ?? { xhigh: "xhigh", max: "max" },
    // Pi drops provider-level compat for extension models, so carry it here.
    compat: { supportsDeveloperRole: false, ...(providerCompat ?? {}) },
  };
}

