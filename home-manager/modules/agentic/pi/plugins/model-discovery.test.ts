import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { test, expect } from "bun:test";
import modelDiscovery from "./model-discovery";

interface Registered {
  id: string;
  config: Record<string, unknown>;
}

const DESKAPP = {
  baseUrl: "http://127.0.0.1:8080/v1",
  api: "openai-completions",
  apiKey: "local",
  discoverModels: true,
  compat: {
    supportsDeveloperRole: false,
    supportsReasoningEffort: true,
    thinkingFormat: "openai",
  },
} as const;

function makeAgentDir(modelsJson: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "model-discovery-test-"));
  fs.writeFileSync(path.join(dir, "models.json"), modelsJson);
  return dir;
}

function providerEntry(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    providers: { deskapp: { ...DESKAPP, ...overrides } },
  });
}

/** Fetch stub returning an OpenAI-style model list; records requests. */
function modelsFetch(ids: string[], calls: Array<{ url: string; auth?: string }>) {
  return async (url: string, init?: RequestInit) => {
    const headers = (init?.headers ?? {}) as Record<string, string>;
    calls.push({ url, auth: headers.Authorization });
    return new Response(
      JSON.stringify({
        data: ids.map((id) => ({ id, object: "model", owned_by: "dotcore" })),
      }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  };
}

const failFetch = async () => {
  throw new Error("connect ECONNREFUSED");
};

function fakePi() {
  const registered: Registered[] = [];
  const api = {
    registerProvider: (id: string, config: Record<string, unknown>) => {
      registered.push({ id, config });
    },
  };
  return { registered, api };
}

async function run(
  dir: string,
  fetchImpl: typeof fetch,
): Promise<Registered[]> {
  const prev = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = dir;
  const realFetch = globalThis.fetch;
  globalThis.fetch = fetchImpl as typeof fetch;
  try {
    const pi = fakePi();
    await modelDiscovery(pi.api);
    return pi.registered;
  } finally {
    globalThis.fetch = realFetch;
    if (prev === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = prev;
  }
}

function modelsOf(entry: Registered | undefined): unknown[] {
  expect(entry).toBeDefined();
  expect(entry.config.models).toBeDefined();
  return entry.config.models as unknown[];
}

const cachePath = (dir: string) =>
  path.join(dir, "extensions", "model-discovery", "cache.json");

test("cache miss fetches, registers parity models, and persists the cache", async () => {
  const dir = makeAgentDir(providerEntry());
  const calls: Array<{ url: string; auth?: string }> = [];
  const registered = await run(dir, modelsFetch(["qwen3.8-27b", "gemma-4-e2b"], calls));

  expect(calls).toEqual([
    { url: "http://127.0.0.1:8080/v1/models", auth: "Bearer local" },
  ]);

  const entry = registered.find((r) => r.id === "deskapp");
  expect(entry.config.baseUrl).toBe(DESKAPP.baseUrl);
  expect(entry.config.api).toBe(DESKAPP.api);

  // Exact model definition: discovered ids get the conservative defaults
  // with the provider compat baked in (Pi drops provider-level compat for
  // extension models).
  const models = modelsOf(entry);
  expect(models).toEqual([
    {
      id: "qwen3.8-27b",
      name: "qwen3.8-27b",
      input: ["text", "image"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      reasoning: true,
      contextWindow: 1_048_576,
      maxTokens: 65_536,
      thinkingLevelMap: { xhigh: "xhigh", max: "max" },
      compat: { ...DESKAPP.compat },
    },
    {
      id: "gemma-4-e2b",
      name: "gemma-4-e2b",
      input: ["text", "image"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      reasoning: true,
      contextWindow: 1_048_576,
      maxTokens: 65_536,
      thinkingLevelMap: { xhigh: "xhigh", max: "max" },
      compat: { ...DESKAPP.compat },
    },
  ]);

  // The cache holds the raw discovered ids; models are constructed at
  // registration time from ids + discoverDefaults.
  const cache = JSON.parse(fs.readFileSync(cachePath(dir), "utf-8"));
  expect(Object.keys(cache.providers)).toEqual(["deskapp"]);
  expect(cache.providers.deskapp.ids).toEqual(["qwen3.8-27b", "gemma-4-e2b"]);
});

test("cache hit registers the cached catalog with zero network", async () => {
  const dir = makeAgentDir(providerEntry());
  await run(dir, modelsFetch(["a", "b"], []));

  const calls: Array<{ url: string; auth?: string }> = [];
  const registered = await run(dir, modelsFetch(["changed"], calls));
  expect(calls).toEqual([]);
  expect(modelsOf(registered.find((r) => r.id === "deskapp")).map((m) => (m as { id: string }).id)).toEqual(["a", "b"]);
});

test("provider compat change invalidates the cache fingerprint", async () => {
  const dir = makeAgentDir(providerEntry());
  await run(dir, modelsFetch(["a"], []));

  fs.writeFileSync(
    path.join(dir, "models.json"),
    providerEntry({ compat: { thinkingFormat: "qwen" } }),
  );
  const calls: Array<{ url: string; auth?: string }> = [];
  const registered = await run(dir, modelsFetch(["b", "c"], calls));
  expect(calls).toHaveLength(1);
  const models = modelsOf(registered.find((r) => r.id === "deskapp"));
  expect(models.map((m) => (m as { id: string }).id)).toEqual(["b", "c"]);
  // The extension always carries its supportsDeveloperRole default.
  expect((models[0] as { compat: Record<string, unknown> }).compat).toEqual({
    supportsDeveloperRole: false,
    thinkingFormat: "qwen",
  });
});

test("fetch failure falls back to the stale cache", async () => {
  const dir = makeAgentDir(providerEntry());
  await run(dir, modelsFetch(["a", "b"], []));

  const registered = await run(dir, failFetch as typeof fetch);
  expect(modelsOf(registered.find((r) => r.id === "deskapp")).map((m) => (m as { id: string }).id)).toEqual(["a", "b"]);
});

test("fetch failure without cache registers the provider without models", async () => {
  const dir = makeAgentDir(providerEntry());
  const registered = await run(dir, failFetch as typeof fetch);

  const entry = registered.find((r) => r.id === "deskapp");
  expect(entry).toBeDefined();
  expect("models" in (entry?.config ?? {})).toBe(false);
  expect(typeof entry?.config.refreshModels).toBe("function");
});

test("offline refresh returns the last list without network", async () => {
  const dir = makeAgentDir(providerEntry());
  const registered = await run(dir, modelsFetch(["a", "b"], []));

  const calls: Array<{ url: string; auth?: string }> = [];
  const refresh = registered[0].config.refreshModels as (
    context: { allowNetwork: boolean; signal: AbortSignal },
  ) => Promise<unknown[]>;
  const result = await refresh({
    allowNetwork: false,
    signal: new AbortController().signal,
  });
  expect(calls).toEqual([]);
  expect((result as Array<{ id: string }>).map((m) => m.id)).toEqual(["a", "b"]);
});

test("online refresh re-fetches, returns the new list, and persists it", async () => {
  const dir = makeAgentDir(providerEntry());
  const registered = await run(dir, modelsFetch(["a"], []));

  const refresh = registered[0].config.refreshModels as (
    context: { allowNetwork: boolean; signal: AbortSignal },
  ) => Promise<unknown[]>;
  const result = await (async () => {
    const calls: Array<{ url: string; auth?: string }> = [];
    const realFetch = globalThis.fetch;
    globalThis.fetch = modelsFetch(["x", "y"], calls) as typeof fetch;
    try {
      return await refresh({
        allowNetwork: true,
        signal: new AbortController().signal,
      });
    } finally {
      globalThis.fetch = realFetch;
    }
  })();
  expect((result as Array<{ id: string }>).map((m) => m.id)).toEqual(["x", "y"]);

  // A subsequent startup with a dead endpoint serves the refreshed catalog.
  const reregistered = await run(dir, failFetch as typeof fetch);
  expect(modelsOf(reregistered.find((r) => r.id === "deskapp")).map((m) => (m as { id: string }).id)).toEqual(["x", "y"]);
});

test("refresh failure returns the last list, never clearing the catalog", async () => {
  const dir = makeAgentDir(providerEntry());
  const registered = await run(dir, modelsFetch(["a"], []));

  const refresh = registered[0].config.refreshModels as (
    context: { allowNetwork: boolean; signal: AbortSignal },
  ) => Promise<unknown[]>;
  const realFetch = globalThis.fetch;
  globalThis.fetch = failFetch as typeof fetch;
  try {
    const result = await refresh({
      allowNetwork: true,
      signal: new AbortController().signal,
    });
    expect((result as Array<{ id: string }>).map((m) => m.id)).toEqual(["a"]);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test("startup fetch failure writes no cache", async () => {
  const dir = makeAgentDir(providerEntry());
  await run(dir, failFetch as typeof fetch);
  expect(fs.existsSync(cachePath(dir))).toBe(false);
});

test("a corrupted cache entry re-fetches", async () => {
  const dir = makeAgentDir(providerEntry());
  // Prime a structurally valid cache, then corrupt the ids.
  await run(dir, modelsFetch(["a"], []));
  const file = cachePath(dir);
  const cache = JSON.parse(fs.readFileSync(file, "utf-8"));
  cache.providers.deskapp.ids = ["a", 42];
  fs.writeFileSync(file, JSON.stringify(cache));

  const calls: Array<{ url: string; auth?: string }> = [];
  const registered = await run(dir, modelsFetch(["b", "c"], calls));
  expect(calls).toHaveLength(1);
  expect(modelsOf(registered.find((r) => r.id === "deskapp")).map((m) => (m as { id: string }).id)).toEqual(["b", "c"]);
});

test("discoverDefaults merge over the built-in defaults", async () => {
  const dir = makeAgentDir(
    providerEntry({
      discoverDefaults: {
        contextWindow: 250_000,
        maxTokens: 32_000,
        input: ["text"],
        reasoning: false,
        thinkingLevelMap: { low: "low", high: "xhigh" },
      },
    }),
  );
  const registered = await run(dir, modelsFetch(["m"], []));
  const models = modelsOf(registered.find((r) => r.id === "deskapp"));
  expect(models).toEqual([
    {
      id: "m",
      name: "m",
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      reasoning: false,
      contextWindow: 250_000,
      maxTokens: 32_000,
      thinkingLevelMap: { low: "low", high: "xhigh" },
      compat: { ...DESKAPP.compat },
    },
  ]);
});

test("a discoverDefaults edit applies at the next startup without a re-fetch", async () => {
  const dir = makeAgentDir(providerEntry());
  await run(dir, modelsFetch(["m"], []));

  fs.writeFileSync(
    path.join(dir, "models.json"),
    providerEntry({ discoverDefaults: { contextWindow: 123_456 } }),
  );
  const calls: Array<{ url: string; auth?: string }> = [];
  const registered = await run(dir, modelsFetch(["changed"], calls));
  expect(calls).toEqual([]);
  const models = modelsOf(registered.find((r) => r.id === "deskapp"));
  expect(models.map((m) => (m as { id: string }).id)).toEqual(["m"]);
  expect((models[0] as { contextWindow: number }).contextWindow).toBe(123_456);
  // Fields without a default keep the built-in parity value.
  expect((models[0] as { maxTokens: number }).maxTokens).toBe(65_536);
});
test("malformed models.json registers nothing and does not throw", async () => {
  const dir = makeAgentDir("{ not json");
  const registered = await run(dir, modelsFetch(["a"], []));
  expect(registered).toEqual([]);
});

test("providers without discoverModels are ignored", async () => {
  const dir = makeAgentDir(
    JSON.stringify({
      providers: {
        deskapp: { ...DESKAPP, discoverModels: false },
        other: { baseUrl: "http://127.0.0.1:9000/v1", api: "openai-completions" },
      },
    }),
  );
  const calls: Array<{ url: string; auth?: string }> = [];
  const registered = await run(dir, modelsFetch(["a"], calls));
  expect(registered).toEqual([]);
  expect(calls).toEqual([]);
});
