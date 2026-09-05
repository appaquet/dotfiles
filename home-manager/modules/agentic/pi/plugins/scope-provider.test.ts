// Unit tests for the scope-provider extension's routing, selection, rollback,
// and summary logic, run against a fake Pi registry and settings (mock.module).
// End-to-end behavior inside a real Pi runtime — real-agent request dispatch
// and cross-session preset inheritance — is out of scope for this suite.

import {
  afterEach,
  beforeEach,
  expect,
  mock,
  test,
} from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

type ProviderConfig = {
  apiKey?: string;
  models?: Model[];
  [key: string]: unknown;
};
type RequestAuth =
  | {
      ok: true;
      apiKey?: string;
      headers?: Record<string, string>;
      baseUrl?: string;
      env?: Record<string, string>;
    }
  | { ok: false; error: string };
type SummaryHandler = (event: any, ctx: TestContext) => Promise<any>;
type Model = {
  provider: string;
  id: string;
  name: string;
  api: string;
  baseUrl: string;
  reasoning: boolean;
  input: string[];
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
  contextWindow: number;
  maxTokens: number;
  samplingParams?: Record<string, number>;
  compat?: { thinkingFormat?: string };
  thinkingLevelMap?: Record<string, string | null>;
};
type ScopeEntry = { model: string; thinking?: string };
type ScopePreset = { main: ScopeEntry; remap: Record<string, ScopeEntry> };
type ScopeConfig = Record<string, ScopePreset>;
type ScopeCommand = (args: string, ctx: TestContext) => Promise<void>;
type ScopeCompletion = (prefix: string) => Array<{
  value: string;
  label: string;
  description?: string;
}> | null;
type ScopeShortcut = (ctx: TestContext) => Promise<void>;
type SessionStartHandler = (
  event: unknown,
  ctx: TestContext,
) => Promise<void>;
type StatusEvent = { key: string; value: string };
type TargetStreamCall = {
  provider: string;
  model: Model;
  context: unknown;
  options: unknown;
};

type SessionEntry = {
  type?: string;
  customType?: string;
  data?: unknown;
  [key: string]: unknown;
};

type TestContext = {
  model: { provider: string; id: string };
  thinkingLevel: string;
  hasUI: boolean;
  cwd: string;
  modelRegistry: TestRegistry;
  sessionManager: { getEntries: () => SessionEntry[] };
  ui: {
    setStatus: (key: string, value: string) => void;
    custom: <T>(factory: (...args: any[]) => unknown) => Promise<T>;
  };
};

class TestRegistry {
  readonly configs = new Map<string, ProviderConfig>();
  readonly models = new Map<string, Model>();
  readonly apiKeys = new Map<
    string,
    string | undefined | (() => Promise<string | undefined>)
  >();
  readonly requestAuth = new Map<string, () => Promise<RequestAuth>>();
  readonly providerStubs = new Map<string, any>();
  readonly providerStreamCalls: TargetStreamCall[] = [];

  find(provider: string, id: string): Model | undefined {
    return this.models.get(`${provider}/${id}`);
  }

  // Target providers complete through their own streamSimple: record the
  // delegated model and forward context/options untouched so alias
  // resolution assertions can inspect the handoff.
  getProvider(provider: string): any {
    let stub = this.providerStubs.get(provider);
    if (!stub) {
      stub = {
        streamSimple: (model: Model, context: unknown, options: unknown) => {
          this.providerStreamCalls.push({
            provider,
            model,
            context,
            options,
          });
          return Promise.resolve(`${provider}-stream`);
        },
      };
      this.providerStubs.set(provider, stub);
    }
    return stub;
  }

  async getApiKeyForProvider(provider: string): Promise<string | undefined> {
    const resolve = this.apiKeys.get(provider);
    return typeof resolve === "function" ? resolve() : resolve;
  }

  async getApiKeyAndHeaders(model: Model): Promise<RequestAuth> {
    const resolve = this.requestAuth.get(`${model.provider}/${model.id}`);
    if (!resolve) return { ok: true, apiKey: `${model.provider}-summary-key` };
    return resolve();
  }

  getRegisteredProviderConfig(provider: string): ProviderConfig | undefined {
    return this.configs.get(provider);
  }

  setScoped(config: ProviderConfig): void {
    const previous = this.configs.get("scoped") ?? {};
    const effective = { ...previous } as ProviderConfig;
    for (const [key, value] of Object.entries(config)) {
      if (value !== undefined) effective[key] = value;
    }
    this.configs.set("scoped", effective);
    for (const key of [...this.models.keys()]) {
      if (key.startsWith("scoped/")) this.models.delete(key);
    }
    for (const model of effective.models ?? []) {
      this.models.set(`scoped/${model.id}`, { ...model, provider: "scoped" });
    }
  }

  unregisterProvider(provider: string): void {
    if (provider !== "scoped")
      throw new Error(`unexpected provider ${provider}`);
    this.configs.delete(provider);
    for (const key of [...this.models.keys()]) {
      if (key.startsWith(`${provider}/`)) this.models.delete(key);
    }
  }
}

type ScopeEntryNotice = {
  type: "custom";
  customType: string;
  data: { text: string; error?: boolean };
};

type Harness = {
  registry: TestRegistry;
  factoryConfig?: ProviderConfig;
  sessionStart: SessionStartHandler;
  startSession: () => Promise<void>;
  ctx: TestContext;
  command: ScopeCommand;
  completions: ScopeCompletion;
  commandDescription: string;
  shortcuts: Array<{
    key: string;
    description: string;
    handler: ScopeShortcut;
  }>;
  summaryHandlers: Record<string, SummaryHandler[]>;
  messages: string[];
  entries: ScopeEntryNotice[];
  sessionEntries: SessionEntry[];
  entryRenderers: Record<
    string,
    (entry: { data: { text: string; error?: boolean } }, options: any, theme: any) => any
  >;
  statuses: StatusEvent[];
  selectorCalls: Array<{
    title: string;
    values: string[];
    initialSearchInput: string;
  }>;
  selection?: string;
  appendEntryFailure?: Error;
  setStatusFailure?: Error;
  restoreFailure: boolean;
};

let agentDir = "";
let testDir = "";
let compactCalls: any[] = [];
let treeCalls: any[] = [];
let compactResult: any;
let treeResult: any;
let compactFailure: Error | undefined;
let treeFailure: Error | undefined;
let retrySettings = { enabled: true, maxRetries: 3, baseDelayMs: 2000 };

// Native stream fallback: the pass-through branch of the scoped streamSimple
// hook reaches into the provider's own api provider, recorded here.
let apiStreamCalls: Array<[any, unknown, unknown]> = [];
const fakeApiProvider = {
  streamSimple: (...args: Array<any>) => {
    apiStreamCalls.push(args as [any, unknown, unknown]);
    return Promise.resolve("native-stream");
  },
};

mock.module("@earendil-works/pi-ai/compat", () => ({
  getApiProvider: () => fakeApiProvider,
}));

// Capture entry-rendered output so the scoped entry renderer can be asserted
// with deterministic styling instead of the real terminal theme.
class FakeText {
  constructor(public readonly rendered: string) {}
}

mock.module("@earendil-works/pi-tui", () => ({
  Text: FakeText,
}));

const nodePath = process.env.NODE_PATH?.split(":")[0];
if (!nodePath) throw new Error("NODE_PATH is required to load Pi's TUI package");
const { fuzzyFilter: nativeFuzzyFilter } = await import(
  join(nodePath, "@earendil-works/pi-tui/dist/fuzzy.js"),
);

mock.module("../lib/fuzzy-selector.ts", () => ({
  filterFuzzyItems: (
    items: Array<{ value: string; label?: string; description?: string }>,
    query: string,
  ) =>
    query
      ? nativeFuzzyFilter(items, query, (item) =>
          [item.value, item.label ?? "", item.description ?? ""]
            .filter(Boolean)
            .join(" "),
        )
      : [...items],
  selectFuzzyItem: async (
    ctx: TestContext,
    title: string,
    items: Array<{ value: string }>,
    initialSearchInput = "",
  ) => {
    const selectorCalls = (ctx as any).__selectorCalls as Harness["selectorCalls"];
    selectorCalls.push({
      title,
      values: items.map((item) => item.value),
      initialSearchInput,
    });
    return ctx.ui.custom<string>(() => undefined);
  },
}));

mock.module("@earendil-works/pi-coding-agent", () => ({
  getAgentDir: () => agentDir,
  SettingsManager: {
    create: () => ({
      getRetrySettings: () => ({ ...retrySettings }),
      getBranchSummarySettings: () => ({
        reserveTokens: 4321,
        skipPrompt: false,
      }),
    }),
  },
  compact: async (...args: any[]) => {
    compactCalls.push(args);
    if (compactFailure) throw compactFailure;
    return compactResult;
  },
  generateBranchSummary: async (...args: any[]) => {
    treeCalls.push(args);
    if (treeFailure) throw treeFailure;
    return treeResult;
  },
}));

beforeEach(() => {
  testDir = mkdtempSync(join(tmpdir(), "scope-provider-test-"));
  agentDir = testDir;
  process.env.PI_SCOPE = "codex";
  delete process.env.PI_SCOPE_REWRITE;
  delete process.env.PI_SCOPE_LOG;
  delete (globalThis as Record<string, unknown>).__PI_SCOPE_SEQ__;
  (globalThis as Record<string, unknown>).activePreset = "codex";
  (globalThis as Record<string, unknown>).upgradedPreset = undefined;
  (globalThis as Record<string, unknown>).rewriteDisabled = false;
  compactCalls = [];
  treeCalls = [];
  apiStreamCalls = [];
  compactResult = {
    summary: "compacted summary",
    firstKeptEntryId: "kept-1",
    tokensBefore: 9876,
    estimatedTokensAfter: 1234,
    usage: {
      input: 10,
      output: 20,
      cacheRead: 3,
      cacheWrite: 4,
      totalTokens: 37,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    details: { readFiles: ["read.ts"], modifiedFiles: ["changed.ts"] },
  };
  treeResult = {
    summary: "branch summary",
    usage: {
      input: 7,
      output: 8,
      cacheRead: 1,
      cacheWrite: 2,
      totalTokens: 18,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    readFiles: ["branch-read.ts"],
    modifiedFiles: ["branch-write.ts"],
  };
  compactFailure = undefined;
  treeFailure = undefined;
  retrySettings = { enabled: true, maxRetries: 3, baseDelayMs: 2000 };
});

afterEach(() => {
  rmSync(testDir, { recursive: true, force: true });
});

async function createHarness(
  config: ScopeConfig,
  options: {
    apiKeys?: Record<
      string,
      string | undefined | (() => Promise<string | undefined>)
    >;
    models?: Model[];
    requestAuth?: Record<string, RequestAuth | (() => Promise<RequestAuth>)>;
    sessionEntries?: SessionEntry[];
    deferSessionStart?: boolean;
  } = {},
): Promise<Harness> {
  writeFileSync(
    join(testDir, "settings.json"),
    JSON.stringify({ scopeProvider: config }),
  );

  const registry = new TestRegistry();
  for (const model of options.models ?? [])
    registry.models.set(`${model.provider}/${model.id}`, model);
  for (const [provider, apiKey] of Object.entries(options.apiKeys ?? {}))
    registry.apiKeys.set(provider, apiKey);
  for (const [key, auth] of Object.entries(options.requestAuth ?? {})) {
    registry.requestAuth.set(
      key,
      typeof auth === "function" ? auth : async () => auth,
    );
  }

  const messages: string[] = [];
  const entries: ScopeEntryNotice[] = [];
  const sessionEntries = [...(options.sessionEntries ?? [])];
  const entryRenderers: Harness["entryRenderers"] = {};
  const statuses: StatusEvent[] = [];
  const selectorCalls: Harness["selectorCalls"] = [];
  let command: ScopeCommand | undefined;
  let completions: ScopeCompletion | undefined;
  let sessionStart: SessionStartHandler | undefined;
  const shortcuts: Array<{
    key: string;
    description: string;
    handler: ScopeShortcut;
  }> = [];
  const summaryHandlers: Record<string, SummaryHandler[]> = {};
  const harness: Harness = {
    registry,
    sessionStart: async () => {
      throw new Error("scope session_start handler was not registered");
    },
    startSession: async () => {
      throw new Error("scope session_start handler was not registered");
    },
    ctx: {
      model: { provider: "scoped", id: "main" },
      thinkingLevel: "medium",
      hasUI: true,
      cwd: testDir,
      modelRegistry: registry,
      sessionManager: { getEntries: () => [...sessionEntries] },
      ui: {
        custom: async <T>() => harness.selection as T,
        setStatus: (key, value) => {
          if (harness.setStatusFailure) throw harness.setStatusFailure;
          statuses.push({ key, value });
        },
      },
    },
    command: async () => {
      throw new Error("scope command was not registered");
    },
    completions: () => {
      throw new Error("scope completions were not registered");
    },
    commandDescription: "",
    shortcuts,
    summaryHandlers,
    messages,
    entries,
    sessionEntries,
    entryRenderers,
    statuses,
    selectorCalls,
    restoreFailure: false,
  };
  const pi = {
    registerProvider: (provider: string, registration: ProviderConfig) => {
      if (provider !== "scoped")
        throw new Error(`unexpected provider ${provider}`);
      if (harness.restoreFailure && registration.apiKey === "old-key")
        throw new Error("restore unavailable");
      registry.setScoped(registration);
    },
    unregisterProvider: (provider: string) =>
      registry.unregisterProvider(provider),
    on: (
      event: string,
      handler:
        | ((event: unknown, ctx: TestContext) => Promise<void>)
        | ((event: { payload: Record<string, unknown> }) => void),
    ) => {
      if (event === "session_start")
        sessionStart = handler as SessionStartHandler;
      if (
        event === "session_before_compact" ||
        event === "session_before_tree"
      ) {
        (summaryHandlers[event] ??= []).push(handler as SummaryHandler);
      }
    },
    registerCommand: (
      _name: string,
      registration: {
        description: string;
        handler: ScopeCommand;
        getArgumentCompletions: ScopeCompletion;
      },
    ) => {
      command = registration.handler;
      completions = registration.getArgumentCompletions;
      harness.commandDescription = registration.description;
    },
    registerShortcut: (
      key: string,
      registration: { description: string; handler: ScopeShortcut },
    ) => {
      shortcuts.push({ key, ...registration });
    },
    // Kept so tests can assert R1: scope must not send LLM-context messages.
    sendMessage: ({ content }: { content: string }) => {
      messages.push(content);
    },
    appendEntry: (customType: string, data: unknown) => {
      if (harness.appendEntryFailure) throw harness.appendEntryFailure;
      const entry = { type: "custom", customType, data };
      sessionEntries.push(entry);
      if (customType === "scoped") entries.push(entry as ScopeEntryNotice);
    },
    registerEntryRenderer: (
      customType: string,
      renderer: Harness["entryRenderers"][string],
    ) => {
      entryRenderers[customType] = renderer;
    },
    setThinkingLevel: (level: string) => {
      harness.ctx.thinkingLevel = level;
    },
  };

  (harness.ctx as any).__selectorCalls = selectorCalls;

  const module = await import(`./scope-provider.ts?${crypto.randomUUID()}`);
  module.default(pi);
  harness.factoryConfig = cloneProviderConfig(
    registry.getRegisteredProviderConfig("scoped"),
  );
  if (!sessionStart || !command || !completions)
    throw new Error("scope extension did not register its handlers");
  harness.sessionStart = sessionStart;
  harness.startSession = () => harness.sessionStart({}, harness.ctx);
  harness.command = command;
  harness.completions = completions;
  if (!options.deferSessionStart) await harness.startSession();
  return harness;
}

// Config snapshots keep function-valued registration hooks (streamSimple)
// by reference: toEqual compares them by identity, so a rollback assertion
// needs the same hook reference on both sides of the comparison.
function cloneProviderConfig(
  config: ProviderConfig | undefined,
): ProviderConfig | undefined {
  if (!config) return undefined;
  const clone: ProviderConfig = {};
  for (const [key, value] of Object.entries(config)) {
    clone[key] = value;
  }
  return clone;
}

// Invoke the scoped provider's registered streamSimple hook the way the
// composed provider does: the scoped model, the caller context, and the
// caller options.
async function scopedStream(
  harness: Harness,
  alias = "main",
  options: any = {},
): Promise<string> {
  const config = harness.registry.getRegisteredProviderConfig("scoped");
  if (!config?.streamSimple)
    throw new Error("scoped provider registration has no streamSimple");
  const model = harness.registry.find("scoped", alias);
  if (!model) throw new Error(`scoped/${alias} is not registered`);
  return await config.streamSimple(model, harness.ctx, options);
}

function lastTargetCall(harness: Harness): TargetStreamCall | undefined {
  return harness.registry.providerStreamCalls.at(-1);
}

function target(provider: string, id: string, name: string): Model {
  return {
    provider,
    id,
    name,
    api: "openai-completions",
    baseUrl: `https://${provider}.test/v1`,
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 128000,
    maxTokens: 8192,
  };
}

const presets: ScopeConfig = {
  codex: {
    main: { model: "old/old-main" },
    remap: { "scoped/summary": { model: "old/old-main", thinking: "low" } },
  },
  noauth: {
    main: { model: "noauth/noauth-main" },
    remap: { "scoped/summary": { model: "noauth/noauth-main", thinking: "low" } },
  },
  unavailable: {
    main: { model: "missing/missing-main" },
    remap: {
      "scoped/summary": { model: "missing/missing-main", thinking: "low" },
    },
  },
  local: {
    main: { model: "next/next-main" },
    remap: { "scoped/summary": { model: "next/next-main", thinking: "low" } },
  },
};

const selectorPresets: ScopeConfig = {
  ...presets,
  local: {
    main: { model: "next/next-main", thinking: "high" },
    remap: { "scoped/summary": { model: "next/next-main", thinking: "low" } },
  },
};

const shortcutPresets: ScopeConfig = {
  codex: {
    main: { model: "old/old-main", thinking: "medium" },
    remap: { "scoped/summary": { model: "old/old-main", thinking: "low" } },
  },
  local: {
    main: { model: "next/next-main", thinking: "high" },
    remap: { "scoped/summary": { model: "next/next-main", thinking: "low" } },
  },
};

const markerPresets: ScopeConfig = {
  codex: {
    main: { model: "old/old-main" },
    remap: {
      "scoped/junior": { model: "old/old-junior", thinking: "high" },
      "scoped/mid": { model: "old/old-main" },
      "scoped/summary": { model: "old/old-junior", thinking: "low" },
    },
  },
  local: {
    main: { model: "next/next-main" },
    remap: {
      "scoped/junior": { model: "next/next-junior", thinking: "low" },
      "scoped/mid": { model: "next/next-main" },
      "scoped/summary": { model: "next/next-junior", thinking: "low" },
    },
  },
};

function markerModels(): Model[] {
  return [
    target("old", "old-main", "Cloud main model"),
    target("old", "old-junior", "Cloud junior model"),
    target("next", "next-main", "Local main model"),
    target("next", "next-junior", "Local junior model"),
  ];
}

function scopedNames(harness: Harness): Record<string, string> {
  return Object.fromEntries(
    (harness.registry.getRegisteredProviderConfig("scoped")?.models ?? []).map(
      (model) => [model.id, model.name],
    ),
  );
}

function processState(): Record<string, unknown> {
  const globals = globalThis as Record<string, unknown>;
  return {
    activePreset: globals.activePreset,
    upgradedPreset: globals.upgradedPreset,
    rewriteDisabled: globals.rewriteDisabled,
  };
}

function modelIdentity(model: Model | undefined):
  | { provider: string; id: string; name: string }
  | undefined {
  return model && {
    provider: model.provider,
    id: model.id,
    name: model.name,
  };
}

test("registers the fixed scope cycling shortcut", async () => {
  const harness = await createHarness(shortcutPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });

  expect(harness.shortcuts).toHaveLength(1);
  expect(harness.shortcuts[0]).toMatchObject({
    key: "ctrl+shift+z",
    description: "Cycle scope preset",
  });
});

test("cycles scopes in configured order and wraps around", async () => {
  const harness = await createHarness(shortcutPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  const cycle = harness.shortcuts[0].handler;

  await cycle(harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "next-key",
  );
  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Local main model [S]",
  );
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.ctx.thinkingLevel).toBe("high");
  expect((globalThis as Record<string, unknown>).activePreset).toBe("local");
  expect((globalThis as Record<string, unknown>).upgradedPreset).toBe("local");
  expect(harness.statuses).toEqual([
    { key: "scope", value: "scope:codex" },
    { key: "scope", value: "scope:local" },
  ]);
  expect(harness.entries).toEqual([
    { type: "custom", customType: "scoped", data: { text: "scope preset: local", error: false } },
  ]);
  expect(harness.messages).toEqual([]);
  await expect(scopedStream(harness)).resolves.toBe("next-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "next",
    model: { provider: "next", id: "next-main" },
  });

  await cycle(harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "old-key",
  );
  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Cloud main model [S]",
  );
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.ctx.thinkingLevel).toBe("medium");
  expect((globalThis as Record<string, unknown>).activePreset).toBe("codex");
  expect((globalThis as Record<string, unknown>).upgradedPreset).toBe("codex");
  expect(harness.statuses).toEqual([
    { key: "scope", value: "scope:codex" },
    { key: "scope", value: "scope:local" },
    { key: "scope", value: "scope:codex" },
  ]);
  expect(harness.entries).toEqual([
    { type: "custom", customType: "scoped", data: { text: "scope preset: local", error: false } },
    { type: "custom", customType: "scoped", data: { text: "scope preset: codex", error: false } },
  ]);
  expect(harness.messages).toEqual([]);
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "old",
    model: { provider: "old", id: "old-main" },
  });
});

test("a failed next scope keeps the existing transaction rollback", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", noauth: undefined },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("noauth", "noauth-main", "Unauthenticated main model"),
    ],
  });
  const cycle = harness.shortcuts[0].handler;
  const previous = cloneProviderConfig(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );

  await cycle(harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    previous,
  );
  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Cloud main model [S]",
  );
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.ctx.thinkingLevel).toBe("medium");
  expect((globalThis as Record<string, unknown>).activePreset).toBe("codex");
  expect((globalThis as Record<string, unknown>).upgradedPreset).toBe("codex");
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(harness.entries).toEqual([
    {
      type: "custom",
      customType: "scoped",
      data: {
        text: 'scope: ERROR — preset "noauth" no credentials resolved for noauth/noauth-main; scoped provider registration was not changed. Check the provider credentials.\nscope: previous preset "codex" restored; alias resolution remains on its targets.',
        error: true,
      },
    },
  ]);
  expect(harness.messages).toEqual([]);
});

test("a successful scope switch persists its structured preset state", async () => {
  delete process.env.PI_SCOPE;
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key", noauth: undefined },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
      target("noauth", "noauth-main", "Unauthenticated main model"),
    ],
  });

  await harness.command("local", harness.ctx);
  await harness.command("noauth", harness.ctx);

  expect(harness.sessionEntries.filter((entry) => entry.customType === "scope-provider-state")).toEqual([
    { type: "custom", customType: "scope-provider-state", data: { preset: "local" } },
  ]);
});

test("persists an explicit launch scope and restores its concrete mappings", async () => {
  const config: ScopeConfig = {
    codex: {
      main: { model: "old/old-main" },
      remap: {
        "scoped/mid": { model: "old/old-main" },
        "scoped/summary": { model: "old/old-main", thinking: "low" },
      },
    },
    go: {
      main: { model: "golang/go-main" },
      remap: {
        "scoped/mid": { model: "golang/go-mid" },
        "scoped/summary": { model: "golang/go-main", thinking: "low" },
      },
    },
  };
  const globals = globalThis as Record<string, unknown>;
  process.env.PI_SCOPE = "go";
  globals.activePreset = undefined;
  globals.upgradedPreset = undefined;
  const launched = await createHarness(config, {
    apiKeys: { old: "old-key", golang: "go-key" },
    models: [
      target("old", "old-main", "Codex model"),
      target("golang", "go-main", "Go main model"),
      target("golang", "go-mid", "Go mid model"),
    ],
  });
  const savedEntries = [...launched.sessionEntries];

  expect(savedEntries).toEqual([
    { type: "custom", customType: "scope-provider-state", data: { preset: "go" } },
  ]);

  delete process.env.PI_SCOPE;
  globals.activePreset = undefined;
  globals.upgradedPreset = undefined;
  const restored = await createHarness(config, {
    apiKeys: { old: "old-key", golang: "go-key" },
    models: [
      target("old", "old-main", "Codex model"),
      target("golang", "go-main", "Go main model"),
      target("golang", "go-mid", "Go mid model"),
    ],
    sessionEntries: savedEntries,
  });

  expect(restored.registry.find("scoped", "main")?.name).toBe(
    "Go main model [S]",
  );
  expect(restored.registry.find("scoped", "mid")?.name).toBe("Go mid model");
  expect(restored.sessionEntries).toEqual(savedEntries);
});

test("does not persist the implicit no-env Codex default", async () => {
  delete process.env.PI_SCOPE;
  const globals = globalThis as Record<string, unknown>;
  globals.activePreset = undefined;
  globals.upgradedPreset = undefined;
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [target("old", "old-main", "Cloud main model")],
  });

  expect(harness.sessionEntries).toEqual([]);
});

test("restores the latest valid persisted preset into concrete main and mid targets", async () => {
  const config: ScopeConfig = {
    codex: {
      main: { model: "old/old-main" },
      remap: {
        "scoped/mid": { model: "old/old-main" },
        "scoped/summary": { model: "old/old-main", thinking: "low" },
      },
    },
    local: {
      main: { model: "deskapp/qwen3.8-27b" },
      remap: {
        "scoped/mid": { model: "deskapp/qwen3.8-27b" },
        "scoped/summary": { model: "deskapp/qwen3.8-27b", thinking: "low" },
      },
    },
  };
  const globals = globalThis as Record<string, unknown>;
  globals.activePreset = "codex";
  globals.upgradedPreset = undefined;
  const logFile = join(testDir, "scope.log");
  process.env.PI_SCOPE_LOG = logFile;
  const harness = await createHarness(config, {
    apiKeys: { old: "old-key", deskapp: "deskapp-key" },
    models: [
      target("old", "old-main", "Codex model"),
      target("deskapp", "qwen3.8-27b", "qwen3.8-27b (deskapp)"),
    ],
    sessionEntries: [
      { type: "custom", customType: "scoped", data: { text: "scope preset: codex" } },
      { type: "custom", customType: "scope-provider-state", data: { preset: "codex" } },
      { type: "custom", customType: "scope-provider-state", data: { preset: 42 } },
      { type: "custom", customType: "scope-provider-state", data: { preset: "removed" } },
      { type: "custom", customType: "scope-provider-state", data: { preset: "local" } },
    ],
  });

  expect(harness.registry.find("scoped", "main")).toMatchObject({
    provider: "scoped",
    id: "main",
    name: "qwen3.8-27b (deskapp) [S]",
  });
  await expect(scopedStream(harness, "main")).resolves.toBe("deskapp-stream");
  await expect(scopedStream(harness, "mid")).resolves.toBe("deskapp-stream");
  expect(harness.registry.providerStreamCalls).toEqual([
    expect.objectContaining({
      provider: "deskapp",
      model: expect.objectContaining({ provider: "deskapp", id: "qwen3.8-27b" }),
    }),
    expect.objectContaining({
      provider: "deskapp",
      model: expect.objectContaining({ provider: "deskapp", id: "qwen3.8-27b" }),
    }),
  ]);
  expect(readFileSync(logFile, "utf8")).toContain(
    'session_start: restore source=session-state preset="local" scoped/main -> deskapp/qwen3.8-27b',
  );
});

test("ignores malformed, unknown, and untyped persisted scope state and uses the launch preset", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
    sessionEntries: [
      { type: "custom", customType: "scope-provider-state", data: undefined },
      { type: "custom", customType: "scope-provider-state", data: { preset: 42 } },
      { type: "custom", customType: "scope-provider-state", data: { preset: "removed" } },
      { type: "custom", customType: "other-state", data: { preset: "local" } },
      { customType: "scope-provider-state", data: { preset: "local" } },
    ],
  });

  expect(harness.registry.find("scoped", "main")?.name).toBe("Cloud main model [S]");
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "old",
    model: { provider: "old", id: "old-main" },
  });
});

test("factory stubs mark only the scoped/main alias", async () => {
  const harness = await createHarness(markerPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: markerModels(),
  });

  const names = Object.fromEntries(
    (harness.factoryConfig?.models ?? []).map(({ id, name }) => [id, name]),
  );

  expect(names).toEqual({
    main: "scoped/main (preset stub, upgraded at session start) [S]",
    junior: "scoped/junior (preset stub, upgraded at session start)",
    mid: "scoped/mid (preset stub, upgraded at session start)",
    senior: "scoped/senior (preset stub, upgraded at session start)",
    staff: "scoped/staff (preset stub, upgraded at session start)",
    principal: "scoped/principal (preset stub, upgraded at session start)",
    reviewer: "scoped/reviewer (preset stub, upgraded at session start)",
  });
});

test("resolves scoped/main in each fresh registry before session_start", async () => {
  // These IDs, keys, and names are synthetic full-thinking fixtures. Production
  // codex maps to openai-codex/gpt-5.6-sol (catalog name "GPT-5.6 Sol [S]")
  // with medium effort; local maps to deskapp/qwen3.8-27b (catalog name
  // "qwen3.8-27b (deskapp) [S]") with medium effort.
  const cases = [
    {
      preset: "codex",
      expected: {
        name: "Cloud main model [S]",
        key: "old-key",
        stream: "old-stream",
        targetModel: { provider: "old", id: "old-main" },
        thinking: "medium",
      },
    },
    {
      preset: "local",
      expected: {
        name: "Local main model [S]",
        key: "next-key",
        stream: "next-stream",
        targetModel: { provider: "next", id: "next-main" },
        thinking: "high",
      },
    },
  ] as const;

  for (const scenario of cases) {
    const globals = globalThis as Record<string, unknown>;
    globals.activePreset = "codex";
    globals.upgradedPreset = undefined;
    globals.rewriteDisabled = false;

    const first = await createHarness(shortcutPresets, {
      apiKeys: { old: "old-key", next: "next-key" },
      models: [
        target("old", "old-main", "Cloud main model"),
        target("next", "next-main", "Local main model"),
      ],
    });
    await first.command(scenario.preset, first.ctx);

    expect(processState()).toEqual({
      activePreset: scenario.preset,
      upgradedPreset: scenario.preset,
      rewriteDisabled: false,
    });
    expect(modelIdentity(first.registry.find("scoped", "main"))).toEqual({
      provider: "scoped",
      id: "main",
      name: scenario.expected.name,
    });

    const second = await createHarness(shortcutPresets, {
      apiKeys: { old: "old-key", next: "next-key" },
      models: [
        target("old", "old-main", "Cloud main model"),
        target("next", "next-main", "Local main model"),
      ],
      deferSessionStart: true,
    });

    expect(modelIdentity(second.registry.find("scoped", "main"))).toEqual({
      provider: "scoped",
      id: "main",
      name: "scoped/main (preset stub, upgraded at session start) [S]",
    });

    await second.startSession();

    expect(modelIdentity(second.registry.find("scoped", "main"))).toEqual({
      provider: "scoped",
      id: "main",
      name: scenario.expected.name,
    });
    expect(second.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
      scenario.expected.key,
    );
    await expect(scopedStream(second)).resolves.toBe(
      scenario.expected.stream,
    );
    expect(lastTargetCall(second)).toMatchObject({
      provider: scenario.expected.targetModel.provider,
      model: scenario.expected.targetModel,
    });
    expect(second.ctx.thinkingLevel).toBe(scenario.expected.thinking);
    expect(processState()).toEqual({
      activePreset: scenario.preset,
      upgradedPreset: scenario.preset,
      rewriteDisabled: false,
    });
  }
});

test("resolves scoped/main when the concrete target uses a non-openai-completions api", async () => {
  const globals = globalThis as Record<string, unknown>;
  globals.activePreset = "local";
  globals.upgradedPreset = undefined;
  globals.rewriteDisabled = false;

  const harness = await createHarness(shortcutPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      { ...target("next", "next-main", "Local main model"), api: "anthropic-messages" },
    ],
  });
  await harness.command("local", harness.ctx);

  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Local main model [S]",
  );
});

test("resolved aliases mark only scoped/main across preset refreshes", async () => {
  const harness = await createHarness(markerPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: markerModels(),
  });

  expect(scopedNames(harness)).toEqual({
    main: "Cloud main model [S]",
    junior: "Cloud junior model",
    mid: "Cloud main model",
  });

  await harness.command("local", harness.ctx);

  expect(scopedNames(harness)).toEqual({
    main: "Local main model [S]",
    junior: "Local junior model",
    mid: "Local main model",
  });

  await harness.command("codex", harness.ctx);

  expect(scopedNames(harness)).toEqual({
    main: "Cloud main model [S]",
    junior: "Cloud junior model",
    mid: "Cloud main model",
  });
});

test("scope completions use configured order and native fuzzy ranking", async () => {
  const harness = await createHarness(selectorPresets, {
    apiKeys: { old: "old-key" },
    models: [target("old", "old-main", "Cloud main model")],
  });

  expect(harness.completions("")).toEqual([
    { value: "codex", label: "codex" },
    { value: "noauth", label: "noauth" },
    { value: "unavailable", label: "unavailable" },
    { value: "local", label: "local" },
  ]);
  expect(harness.completions("LC")).toEqual([
    { value: "local", label: "local" },
  ]);
  expect(harness.completions("zzz")).toBeNull();
});

test("a UI selection uses configured order and the transactional switch path", async () => {
  const harness = await createHarness(selectorPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  harness.selection = "local";

  await harness.command("", harness.ctx);

  expect(harness.commandDescription).toBe(
    "Select a preset with /scope, or switch directly with /scope <preset>",
  );
  expect(harness.selectorCalls).toEqual([
    {
      title: "Select scope:",
      values: ["codex", "noauth", "unavailable", "local"],
      initialSearchInput: "",
    },
  ]);
  expect(harness.entries).toEqual([
    { type: "custom", customType: "scoped", data: { text: "scope preset: local", error: false } },
  ]);
  expect(harness.messages).toEqual([]);
  expect(harness.statuses).toEqual([
    { key: "scope", value: "scope:codex" },
    { key: "scope", value: "scope:local" },
  ]);
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.ctx.thinkingLevel).toBe("high");
  expect((globalThis as Record<string, unknown>).activePreset).toBe("local");
  expect((globalThis as Record<string, unknown>).upgradedPreset).toBe("local");
  expect((globalThis as Record<string, unknown>).rewriteDisabled).toBe(false);
  expect(harness.registry.find("scoped", "main")).toMatchObject({
    provider: "scoped",
    id: "main",
  });
  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Local main model [S]",
  );
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "next-key",
  );
  await expect(scopedStream(harness)).resolves.toBe("next-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "next",
    model: { provider: "next", id: "next-main" },
  });
});

test("partial and unmatched scope arguments open a prefilled selector", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  harness.selection = "local";

  await harness.command("  ocl  ", harness.ctx);

  expect(harness.selectorCalls).toEqual([
    {
      title: "Select scope:",
      values: ["codex", "noauth", "unavailable", "local"],
      initialSearchInput: "ocl",
    },
  ]);
  expect(harness.entries).toEqual([
    { type: "custom", customType: "scoped", data: { text: "scope preset: local", error: false } },
  ]);

  harness.selection = undefined;
  await harness.command("zzz", harness.ctx);

  expect(harness.selectorCalls.at(-1)).toEqual({
    title: "Select scope:",
    values: ["codex", "noauth", "unavailable", "local"],
    initialSearchInput: "zzz",
  });
  expect(harness.entries).toHaveLength(1);
});

test("cancelling the UI selector is a complete no-op", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  const beforeConfig = cloneProviderConfig(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );
  const beforeModel = { ...harness.ctx.model };
  const beforeThinking = harness.ctx.thinkingLevel;
  const beforeStatuses = [...harness.statuses];
  const beforeEntries = [...harness.entries];
  const beforeStream = await scopedStream(harness);
  const beforeProcess = {
    activePreset: (globalThis as Record<string, unknown>).activePreset,
    upgradedPreset: (globalThis as Record<string, unknown>).upgradedPreset,
    rewriteDisabled: (globalThis as Record<string, unknown>).rewriteDisabled,
  };

  await harness.command("", harness.ctx);

  expect(harness.selectorCalls).toEqual([
    {
      title: "Select scope:",
      values: ["codex", "noauth", "unavailable", "local"],
      initialSearchInput: "",
    },
  ]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    beforeConfig,
  );
  expect(harness.ctx.model).toEqual(beforeModel);
  expect(harness.ctx.thinkingLevel).toBe(beforeThinking);
  expect(harness.statuses).toEqual(beforeStatuses);
  expect(harness.entries).toEqual(beforeEntries);
  const afterStream = await scopedStream(harness);
  expect(afterStream).toBe(beforeStream);
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "old",
    model: { provider: "old", id: "old-main" },
  });
  expect({
    activePreset: (globalThis as Record<string, unknown>).activePreset,
    upgradedPreset: (globalThis as Record<string, unknown>).upgradedPreset,
    rewriteDisabled: (globalThis as Record<string, unknown>).rewriteDisabled,
  }).toEqual(beforeProcess);
});

test("a selected current preset keeps direct same-preset behavior", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [target("old", "old-main", "Cloud main model")],
  });
  harness.selection = "codex";
  const beforeConfig = cloneProviderConfig(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );

  await harness.command("", harness.ctx);

  expect(harness.selectorCalls).toEqual([
    {
      title: "Select scope:",
      values: ["codex", "noauth", "unavailable", "local"],
      initialSearchInput: "",
    },
  ]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    beforeConfig,
  );
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.entries).toEqual([
    {
      type: "custom",
      customType: "scoped",
      data: { text: 'already on preset "codex"', error: false },
    },
  ]);
  expect(harness.messages).toEqual([]);
});

test("non-UI scope rejects selector-requiring input but accepts exact input", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  harness.ctx.hasUI = false;

  await expect(harness.command("", harness.ctx)).rejects.toThrow(
    "/scope requires interactive UI when no exact preset is provided",
  );
  await expect(harness.command("loc", harness.ctx)).rejects.toThrow(
    "/scope requires interactive UI when no exact preset is provided",
  );
  expect(harness.selectorCalls).toEqual([]);

  await harness.command("local", harness.ctx);

  expect(harness.entries).toEqual([
    { type: "custom", customType: "scoped", data: { text: "scope preset: local", error: false } },
  ]);
  expect(harness.ctx.thinkingLevel).toBe("medium");
});

test("scope notices render one line and never use LLM-context messages", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });

  const renderer = harness.entryRenderers["scoped"];
  expect(renderer).toBeDefined();

  // Deterministic style stub: records the theme token instead of ANSI codes.
  const fg = (token: string, text: string) => `[${token}]${text}`;
  const switchNotice = renderer(
    { data: { text: "scope preset: local", error: false } },
    { expanded: false },
    { fg },
  );
  expect((switchNotice as FakeText).rendered).toBe(
    "[customMessageText]scope preset: local",
  );
  const errorNotice = renderer(
    { data: { text: "scope: ERROR — preset exploded", error: true } },
    { expanded: false },
    { fg },
  );
  expect((errorNotice as FakeText).rendered).toBe(
    "[error]scope: ERROR — preset exploded",
  );

  await harness.command("local", harness.ctx);
  await harness.command("local", harness.ctx);

  expect(harness.entries).toEqual([
    { type: "custom", customType: "scoped", data: { text: "scope preset: local", error: false } },
    {
      type: "custom",
      customType: "scoped",
      data: { text: 'already on preset "local"', error: false },
    },
  ]);
  // R1: no scope notice may reach LLM context as a session message.
  expect(harness.messages).toEqual([]);
});

test("a selected failed switch rolls back like a direct argument", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", noauth: undefined },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("noauth", "noauth-main", "Unauthenticated main model"),
    ],
  });
  const previous = cloneProviderConfig(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );
  harness.selection = "noauth";

  await harness.command("", harness.ctx);

  expect(harness.selectorCalls).toEqual([
    {
      title: "Select scope:",
      values: ["codex", "noauth", "unavailable", "local"],
      initialSearchInput: "",
    },
  ]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    previous,
  );
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.ctx.thinkingLevel).toBe("medium");
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(harness.entries.at(-1)?.data).toEqual({
    text: 'scope: ERROR — preset "noauth" no credentials resolved for noauth/noauth-main; scoped provider registration was not changed. Check the provider credentials.\nscope: previous preset "codex" restored; alias resolution remains on its targets.',
    error: true,
  });
});

test("missing target auth preserves the previous scoped provider and alias table", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", noauth: undefined, next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("noauth", "noauth-main", "Unauthenticated main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  const previous = harness.registry.getRegisteredProviderConfig("scoped");

  await harness.command("noauth", harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    previous,
  );
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "old-key",
  );
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.entries.at(-1)?.data.text).toContain(
    'previous preset "codex" restored',
  );
});

test("an unresolvable target rolls back to the previous provider and alias table", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });

  await harness.command("unavailable", harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "old-key",
  );
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.entries.at(-1)?.data.text).toContain(
    'previous preset "codex" restored',
  );
});

test("a failed registry rollback disables alias resolution and requires a restart", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  harness.setStatusFailure = new Error("status failed");
  harness.restoreFailure = true;

  await harness.command("local", harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "next-key",
  );
  // The cleared alias table makes completions pass through to native behavior.
  await expect(scopedStream(harness)).resolves.toBe("native-stream");
  expect(harness.registry.providerStreamCalls).toEqual([]);
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.entries.at(-1)?.data.text).toContain("restart the session");
});

test("repeated switches refresh scoped/main and preserve concrete selections", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });

  expect(harness.registry.find("scoped", "main")).toMatchObject({
    provider: "scoped",
    id: "main",
  });
  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Cloud main model [S]",
  );

  await harness.command("local", harness.ctx);
  expect(harness.statuses).toEqual([
    { key: "scope", value: "scope:codex" },
    { key: "scope", value: "scope:local" },
  ]);
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")).toMatchObject({
    provider: "scoped",
    id: "main",
  });
  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Local main model [S]",
  );
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "next-key",
  );
  await expect(scopedStream(harness)).resolves.toBe("next-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "next",
    model: { provider: "next", id: "next-main" },
  });

  await harness.command("codex", harness.ctx);
  expect(harness.statuses).toEqual([
    { key: "scope", value: "scope:codex" },
    { key: "scope", value: "scope:local" },
    { key: "scope", value: "scope:codex" },
  ]);
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")).toMatchObject({
    provider: "scoped",
    id: "main",
  });
  expect(harness.registry.find("scoped", "main")?.name).toBe(
    "Cloud main model [S]",
  );
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "old-key",
  );
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "old",
    model: { provider: "old", id: "old-main" },
  });

  harness.ctx.model = { provider: "old", id: "old-main" };
  await harness.command("local", harness.ctx);
  expect(harness.ctx.model).toEqual({ provider: "old", id: "old-main" });
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "next-key",
  );
});

test("scoped streamSimple delegates parent and child aliases to exact concrete targets", async () => {
  const harness = await createHarness(markerPresets, {
    apiKeys: { old: "old-key" },
    models: markerModels(),
  });
  const mainContext = {};
  const mainOptions = { reasoning: "medium" };

  await expect(
    scopedStream(harness, "main", mainOptions),
  ).resolves.toBe("old-stream");
  await expect(scopedStream(harness, "junior")).resolves.toBe("old-stream");

  const [mainCall, juniorCall] = harness.registry.providerStreamCalls;
  expect(mainCall?.model).toBe(harness.registry.find("old", "old-main"));
  expect(juniorCall?.model).toBe(
    harness.registry.find("old", "old-junior"),
  );
  // Context and options reach the target provider untouched: alias
  // resolution only swaps the model, never the completion parameters.
  expect(mainCall).toMatchObject({ provider: "old" });
  expect(mainCall?.context).toBe(harness.ctx);
  expect(mainCall?.options).toBe(mainOptions);
});

test("aliases without a target resolve pre-upgrade stubs natively", async () => {
  const harness = await createHarness(markerPresets, {
    apiKeys: { old: "old-key" },
    models: markerModels(),
    deferSessionStart: true,
  });
  const stub = harness.registry.find("scoped", "senior");
  if (!stub) throw new Error("scoped/senior stub was not registered");
  const options = { reasoning: "low" };

  await expect(
    harness.registry.getRegisteredProviderConfig("scoped")?.streamSimple?.(
      stub,
      harness.ctx,
      options,
    ),
  ).resolves.toBe("native-stream");
  expect(apiStreamCalls).toEqual([[stub, harness.ctx, options]]);
});

test("the PI_SCOPE_REWRITE kill switch forces native pass-through", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [target("old", "old-main", "Cloud main model")],
  });
  process.env.PI_SCOPE_REWRITE = "0";

  await expect(scopedStream(harness)).resolves.toBe("native-stream");
  expect(harness.registry.providerStreamCalls).toEqual([]);
  expect(apiStreamCalls).toHaveLength(1);
});

test("a target preset pointing at the scoped provider rejects as a cycle", async () => {
  (globalThis as Record<string, unknown>).activePreset = "cyclic";
  const harness = await createHarness(
    { cyclic: { main: { model: "scoped/main" }, remap: {} } },
    { apiKeys: { scoped: "scoped-key" } },
  );

  await expect(scopedStream(harness)).rejects.toThrow(
    /scoped\/main targets scoped\/main: a scoped alias cannot resolve to another scoped alias/,
  );
  expect(harness.registry.providerStreamCalls).toEqual([]);
});

test("registers one native summary handler per event and declines direct models", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [target("old", "old-main", "Cloud main model")],
  });
  expect(harness.summaryHandlers.session_before_compact).toHaveLength(1);
  expect(harness.summaryHandlers.session_before_tree).toHaveLength(1);

  harness.ctx.model = { provider: "old", id: "old-main" };
  const signal = new AbortController().signal;
  await expect(
    harness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal },
      harness.ctx,
    ),
  ).resolves.toBeUndefined();
  await expect(
    harness.summaryHandlers.session_before_tree[0](
      {
        preparation: { userWantsSummary: true, entriesToSummarize: [{}] },
        signal,
      },
      harness.ctx,
    ),
  ).resolves.toBeUndefined();
  expect(compactCalls).toEqual([]);
  expect(treeCalls).toEqual([]);
});

test("passes native compaction state and exact concrete request configuration through unchanged", async () => {
  const concrete = {
    ...target("old", "old-main", "Cloud main model"),
    thinkingLevelMap: { high: "xhigh" },
  };
  const harness = await createHarness(
    {
      codex: {
        main: { model: "old/old-main", thinking: "high" },
        remap: { "scoped/summary": { model: "old/old-main", thinking: "high" } },
      },
    },
    {
      apiKeys: { old: "old-key" },
      models: [concrete],
      requestAuth: {
        "old/old-main": {
          ok: true,
          apiKey: "resolved-key",
          baseUrl: "https://resolved.test/v1",
          headers: { "x-auth": "resolved" },
          env: { AUTH_ENV: "resolved" },
        },
      },
    },
  );
  const preparation = {
    firstKeptEntryId: "kept-1",
    messagesToSummarize: [{ role: "user", content: "old" }],
    turnPrefixMessages: [{ role: "user", content: "split" }],
    isSplitTurn: true,
    tokensBefore: 9876,
    previousSummary: "previous summary",
    fileOps: { read: ["read.ts"], modified: ["changed.ts"] },
    settings: { enabled: true, reserveTokens: 123, keepRecentTokens: 456 },
  };
  const controller = new AbortController();

  const result = await harness.summaryHandlers.session_before_compact[0](
    {
      preparation,
      customInstructions: "focus on decisions",
      reason: "overflow",
      willRetry: true,
      signal: controller.signal,
    },
    harness.ctx,
  );

  expect(result).toEqual({ compaction: compactResult });
  expect(compactCalls).toEqual([
    [
      preparation,
      { ...concrete, baseUrl: "https://resolved.test/v1" },
      "resolved-key",
      { "x-auth": "resolved" },
      "focus on decisions",
      controller.signal,
      "high",
      undefined,
      { AUTH_ENV: "resolved" },
      { enabled: true, maxRetries: 3, baseDelayMs: 2000 },
    ],
  ]);
});

test("passes branch instructions, reserve, retry, usage and file details through native generation", async () => {
  const concrete = target("old", "old-main", "Cloud main model");
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [concrete],
    requestAuth: {
      "old/old-main": {
        ok: true,
        apiKey: "tree-key",
        headers: { "x-tree": "yes" },
        env: { TREE_ENV: "yes" },
      },
    },
  });
  const entries = [{ type: "message", id: "entry-1" }];
  const signal = new AbortController().signal;

  const result = await harness.summaryHandlers.session_before_tree[0](
    {
      preparation: {
        userWantsSummary: true,
        entriesToSummarize: entries,
        customInstructions: "tree focus",
        replaceInstructions: true,
      },
      signal,
    },
    harness.ctx,
  );

  expect(treeCalls).toEqual([
    [
      entries,
      {
        model: concrete,
        apiKey: "tree-key",
        headers: { "x-tree": "yes" },
        env: { TREE_ENV: "yes" },
        signal,
        customInstructions: "tree focus",
        replaceInstructions: true,
        reserveTokens: 4321,
        retry: { enabled: true, maxRetries: 3, baseDelayMs: 2000 },
      },
    ],
  ]);
  expect(result).toEqual({
    summary: {
      summary: "branch summary",
      usage: treeResult.usage,
      details: {
        readFiles: ["branch-read.ts"],
        modifiedFiles: ["branch-write.ts"],
      },
    },
  });
});

test("declines tree generation when no summary is requested or there are no entries", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [target("old", "old-main", "Cloud main model")],
  });
  const signal = new AbortController().signal;

  await expect(
    harness.summaryHandlers.session_before_tree[0](
      {
        preparation: { userWantsSummary: false, entriesToSummarize: [{}] },
        signal,
      },
      harness.ctx,
    ),
  ).resolves.toBeUndefined();
  await expect(
    harness.summaryHandlers.session_before_tree[0](
      {
        preparation: { userWantsSummary: true, entriesToSummarize: [] },
        signal,
      },
      harness.ctx,
    ),
  ).resolves.toBeUndefined();
  expect(treeCalls).toEqual([]);
});

test("compaction and branch summaries use the dedicated summary target, not the active work alias", async () => {
  const mainModel = target("old", "old-main", "Cloud main model");
  const summaryModel = target("old", "old-junior", "Cloud junior model");
  const harness = await createHarness(
    {
      codex: {
        main: { model: "old/old-main", thinking: "xhigh" },
        remap: {
          "scoped/junior": { model: "old/old-junior", thinking: "off" },
          "scoped/summary": { model: "old/old-junior", thinking: "low" },
        },
      },
    },
    {
      apiKeys: { old: "old-key" },
      models: [mainModel, summaryModel],
      requestAuth: {
        "old/old-main": { ok: true, apiKey: "main-key" },
        "old/old-junior": { ok: true, apiKey: "summary-key" },
      },
    },
  );
  const signal = new AbortController().signal;

  // Compaction routes to the dedicated summary model with its own thinking
  // level, independent of the active scoped/main work alias.
  await harness.summaryHandlers.session_before_compact[0](
    { preparation: { firstKeptEntryId: "kept" }, signal },
    harness.ctx,
  );
  expect(compactCalls).toHaveLength(1);
  expect(compactCalls[0][1]).toEqual(summaryModel);
  expect(compactCalls[0][2]).toBe("summary-key");
  expect(compactCalls[0][6]).toBe("low");

  // Branch summaries use the same dedicated summary model and credentials.
  await harness.summaryHandlers.session_before_tree[0](
    {
      preparation: { userWantsSummary: true, entriesToSummarize: [{}] },
      signal,
    },
    harness.ctx,
  );
  expect(treeCalls).toHaveLength(1);
  expect(treeCalls[0][1].model).toEqual(summaryModel);
  expect(treeCalls[0][1].apiKey).toBe("summary-key");
});

test("scoped/summary is validated but never exposed as a selectable work model", async () => {
  const harness = await createHarness(markerPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: markerModels(),
  });
  const names = scopedNames(harness);
  expect(names.main).toBeDefined();
  expect(names.junior).toBeDefined();
  expect(names.summary).toBeUndefined();
});

test("a preset without a scoped/summary entry fails registration and keeps the stub", async () => {
  const harness = await createHarness(
    { codex: { main: { model: "old/old-main" }, remap: {} } },
    {
      apiKeys: { old: "old-key" },
      models: [target("old", "old-main", "Cloud main model")],
    },
  );
  expect(harness.entries.at(-1)?.data).toEqual({
    text: 'scope: ERROR — preset "codex" has no resolvable scoped/summary target; compaction and /tree branch summaries would be cancelled. Check the scopeProvider settings and models.',
    error: true,
  });
  expect(harness.messages).toEqual([]);
  expect(scopedNames(harness).main).toBe(
    "scoped/main (preset stub, upgraded at session start) [S]",
  );
});

test("a scoped/summary target absent from the registry fails registration clearly", async () => {
  const harness = await createHarness(
    {
      codex: {
        main: { model: "old/old-main" },
        remap: { "scoped/summary": { model: "old/old-missing", thinking: "low" } },
      },
    },
    {
      apiKeys: { old: "old-key" },
      models: [target("old", "old-main", "Cloud main model")],
    },
  );
  expect(harness.entries.at(-1)?.data).toEqual({
    text: 'scope: ERROR — preset "codex" has no resolvable scoped/summary target; compaction and /tree branch summaries would be cancelled. Check the scopeProvider settings and models.',
    error: true,
  });
  expect(harness.messages).toEqual([]);
  expect(scopedNames(harness).main).toBe(
    "scoped/main (preset stub, upgraded at session start) [S]",
  );
});

test("a summary event cancels without native fallback when the dedicated target becomes unavailable", async () => {
  const mainModel = target("old", "old-main", "Cloud main model");
  const summaryModel = target("old", "old-junior", "Cloud junior model");
  const harness = await createHarness(
    {
      codex: {
        main: { model: "old/old-main" },
        remap: { "scoped/summary": { model: "old/old-junior", thinking: "low" } },
      },
    },
    { apiKeys: { old: "old-key" }, models: [mainModel, summaryModel] },
  );
  harness.registry.models.delete("old/old-junior");
  const signal = new AbortController().signal;
  await expect(
    harness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal },
      harness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
  expect(compactCalls).toEqual([]);
  expect(harness.entries.at(-1)?.data.text).toContain(
    "concrete target old/old-junior is unavailable",
  );
  expect(harness.entries.at(-1)?.data.error).toBe(true);
});

test("summaries observe only committed targets across deferred failure and successful scope commit", async () => {
  let rejectCredential!: (error: Error) => void;
  let credentialStarted!: () => void;
  const started = new Promise<void>((resolve) => {
    credentialStarted = resolve;
  });
  const pendingCredential = new Promise<string | undefined>(
    (_resolve, reject) => {
      rejectCredential = reject;
    },
  );
  const oldModel = target("old", "old-main", "Cloud main model");
  const nextModel = target("next", "next-main", "Local main model");
  const harness = await createHarness(selectorPresets, {
    apiKeys: {
      old: "old-key",
      next: async () => {
        credentialStarted();
        return pendingCredential;
      },
    },
    models: [oldModel, nextModel],
    requestAuth: {
      "old/old-main": { ok: true, apiKey: "old-summary-key" },
      "next/next-main": { ok: true, apiKey: "next-summary-key" },
    },
  });
  const event = {
    preparation: { firstKeptEntryId: "kept" },
    signal: new AbortController().signal,
  };

  const switching = harness.command("local", harness.ctx);
  await started;
  await harness.summaryHandlers.session_before_compact[0](event, harness.ctx);

  expect(compactCalls).toHaveLength(1);
  expect(compactCalls[0][1]).toEqual(oldModel);
  expect(compactCalls[0][2]).toBe("old-summary-key");
  rejectCredential(new Error("credential lookup failed"));
  await switching;
  await expect(scopedStream(harness)).resolves.toBe("old-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "old",
    model: { provider: "old", id: "old-main" },
  });

  harness.registry.apiKeys.set("next", "next-key");
  await harness.command("local", harness.ctx);
  await harness.summaryHandlers.session_before_compact[0](event, harness.ctx);

  expect(compactCalls).toHaveLength(2);
  expect(compactCalls[1][1]).toEqual(nextModel);
  expect(compactCalls[1][2]).toBe("next-summary-key");
  await expect(scopedStream(harness)).resolves.toBe("next-stream");
  expect(lastTargetCall(harness)).toMatchObject({
    provider: "next",
    model: { provider: "next", id: "next-main" },
  });
});

test("snapshots the concrete summary target before deferred auth and a scope switch", async () => {
  let releaseAuth!: (auth: RequestAuth) => void;
  let authStarted!: () => void;
  const started = new Promise<void>((resolve) => {
    authStarted = resolve;
  });
  const pendingAuth = new Promise<RequestAuth>((resolve) => {
    releaseAuth = resolve;
  });
  const oldModel = target("old", "old-main", "Cloud main model");
  const nextModel = target("next", "next-main", "Local main model");
  const harness = await createHarness(
    {
      codex: {
        main: { model: "old/old-main" },
        remap: { "scoped/summary": { model: "old/old-main" } },
      },
      local: {
        main: { model: "next/next-main" },
        remap: { "scoped/summary": { model: "next/next-main" } },
      },
    },
    {
      apiKeys: { old: "old-key", next: "next-key" },
      models: [oldModel, nextModel],
      requestAuth: {
        "old/old-main": async () => {
          authStarted();
          return pendingAuth;
        },
        "next/next-main": { ok: true, apiKey: "next-summary-key" },
      },
    },
  );
  const event = {
    preparation: { firstKeptEntryId: "kept" },
    signal: new AbortController().signal,
  };
  const inFlight = harness.summaryHandlers.session_before_compact[0](
    event,
    harness.ctx,
  );
  await started;

  await harness.command("local", harness.ctx);
  releaseAuth({ ok: true, apiKey: "old-summary-key" });
  await inFlight;

  expect(compactCalls[0][1]).toEqual(oldModel);
  expect(compactCalls[0][2]).toBe("old-summary-key");
  expect(compactCalls[0][6]).toBe("medium");
});

test("reports auth and generation failures and cancels without alias fallback", async () => {
  const concrete = target("old", "old-main", "Cloud main model");
  const authHarness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [concrete],
    requestAuth: { "old/old-main": { ok: false, error: "credential expired" } },
  });
  const signal = new AbortController().signal;
  await expect(
    authHarness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal },
      authHarness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
  expect(compactCalls).toEqual([]);
  expect(authHarness.entries.at(-1)?.data).toEqual({
    text: "scope: ERROR — compaction with old/old-main failed: credential expired. Check the target model and credentials, then retry.",
    error: true,
  });

  authHarness.appendEntryFailure = new Error("entry sink unavailable");
  await expect(
    authHarness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal },
      authHarness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
  expect(compactCalls).toEqual([]);
  // The entry sink failure is swallowed: no second notice is recorded.
  expect(authHarness.entries).toHaveLength(1);

  treeFailure = new Error("non-retryable invalid request");
  const generationHarness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [concrete],
  });
  await expect(
    generationHarness.summaryHandlers.session_before_tree[0](
      {
        preparation: { userWantsSummary: true, entriesToSummarize: [{}] },
        signal,
      },
      generationHarness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
  expect(generationHarness.entries.at(-1)?.data).toEqual({
    text: "scope: ERROR — branch summary with old/old-main failed: non-retryable invalid request. Check the target model and credentials, then retry.",
    error: true,
  });
});

test("forwards configured retry policy and cancels retry exhaustion, disabled retry and abort outcomes", async () => {
  const concrete = target("old", "old-main", "Cloud main model");
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [concrete],
  });
  const signal = new AbortController().signal;
  compactFailure = new Error("retry attempts exhausted");
  await expect(
    harness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal },
      harness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
  expect(compactCalls[0][9]).toEqual({
    enabled: true,
    maxRetries: 3,
    baseDelayMs: 2000,
  });

  compactCalls = [];
  compactFailure = new Error("retry disabled failure");
  retrySettings = { enabled: false, maxRetries: 0, baseDelayMs: 5 };
  await expect(
    harness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal },
      harness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
  expect(compactCalls[0][9]).toEqual({
    enabled: false,
    maxRetries: 0,
    baseDelayMs: 5,
  });

  compactFailure = undefined;
  const controller = new AbortController();
  controller.abort();
  await expect(
    harness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal: controller.signal },
      harness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
});
