import { afterEach, beforeEach, expect, mock, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
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
type ScopeHandler = (event: { payload: Record<string, unknown> }) => void;
type ScopeShortcut = (ctx: TestContext) => Promise<void>;
type SessionStartHandler = (
  event: unknown,
  ctx: TestContext,
) => Promise<void>;
type StatusEvent = { key: string; value: string };

type TestContext = {
  model: { provider: string; id: string };
  thinkingLevel: string;
  hasUI: boolean;
  cwd: string;
  modelRegistry: TestRegistry;
  ui: {
    setStatus: (key: string, value: string) => void;
    select: (title: string, options: string[]) => Promise<string | undefined>;
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

  find(provider: string, id: string): Model | undefined {
    return this.models.get(`${provider}/${id}`);
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

type Harness = {
  registry: TestRegistry;
  factoryConfig?: ProviderConfig;
  sessionStart: SessionStartHandler;
  startSession: () => Promise<void>;
  ctx: TestContext;
  command: ScopeCommand;
  commandDescription: string;
  shortcuts: Array<{
    key: string;
    description: string;
    handler: ScopeShortcut;
  }>;
  beforeRequest: ScopeHandler;
  summaryHandlers: Record<string, SummaryHandler[]>;
  messages: string[];
  statuses: StatusEvent[];
  selectCalls: Array<{ title: string; options: string[] }>;
  selection?: string;
  sendMessageFailure?: Error;
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
  delete (globalThis as Record<string, unknown>).__PI_SCOPE_SEQ__;
  (globalThis as Record<string, unknown>).activePreset = "codex";
  (globalThis as Record<string, unknown>).upgradedPreset = undefined;
  (globalThis as Record<string, unknown>).rewriteDisabled = false;
  compactCalls = [];
  treeCalls = [];
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
  const statuses: StatusEvent[] = [];
  const selectCalls: Array<{ title: string; options: string[] }> = [];
  let command: ScopeCommand | undefined;
  let beforeRequest: ScopeHandler | undefined;
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
      ui: {
        select: async (title, options) => {
          selectCalls.push({ title, options });
          return harness.selection;
        },
        setStatus: (key, value) => {
          if (harness.setStatusFailure) throw harness.setStatusFailure;
          statuses.push({ key, value });
        },
      },
    },
    command: async () => {
      throw new Error("scope command was not registered");
    },
    commandDescription: "",
    shortcuts,
    beforeRequest: () => {
      throw new Error("before_provider_request handler was not registered");
    },
    summaryHandlers,
    messages,
    statuses,
    selectCalls,
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
        | ScopeHandler
        | ((event: unknown, ctx: TestContext) => Promise<void>),
    ) => {
      if (event === "before_provider_request")
        beforeRequest = handler as ScopeHandler;
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
      registration: { description: string; handler: ScopeCommand },
    ) => {
      command = registration.handler;
      harness.commandDescription = registration.description;
    },
    registerShortcut: (
      key: string,
      registration: { description: string; handler: ScopeShortcut },
    ) => {
      shortcuts.push({ key, ...registration });
    },
    sendMessage: ({ content }: { content: string }) => {
      if (harness.sendMessageFailure) throw harness.sendMessageFailure;
      messages.push(content);
    },
    setThinkingLevel: (level: string) => {
      harness.ctx.thinkingLevel = level;
    },
  };

  const module = await import(`./scope-provider.ts?${crypto.randomUUID()}`);
  module.default(pi);
  harness.factoryConfig = structuredClone(
    registry.getRegisteredProviderConfig("scoped"),
  );
  if (!sessionStart || !command || !beforeRequest)
    throw new Error("scope extension did not register its handlers");
  harness.sessionStart = sessionStart;
  harness.startSession = () => harness.sessionStart({}, harness.ctx);
  harness.command = command;
  harness.beforeRequest = beforeRequest;
  if (!options.deferSessionStart) await harness.startSession();
  return harness;
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
  codex: { main: { model: "old/old-main" }, remap: {} },
  noauth: { main: { model: "noauth/noauth-main" }, remap: {} },
  unavailable: { main: { model: "missing/missing-main" }, remap: {} },
  local: { main: { model: "next/next-main" }, remap: {} },
};

const selectorPresets: ScopeConfig = {
  ...presets,
  local: { main: { model: "next/next-main", thinking: "high" }, remap: {} },
};

const shortcutPresets: ScopeConfig = {
  codex: { main: { model: "old/old-main", thinking: "medium" }, remap: {} },
  local: { main: { model: "next/next-main", thinking: "high" }, remap: {} },
};

const markerPresets: ScopeConfig = {
  codex: {
    main: { model: "old/old-main" },
    remap: {
      "scoped/junior": { model: "old/old-junior", thinking: "high" },
      "scoped/mid": { model: "old/old-main" },
    },
  },
  local: {
    main: { model: "next/next-main" },
    remap: {
      "scoped/junior": { model: "next/next-junior", thinking: "low" },
      "scoped/mid": { model: "next/next-main" },
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

function rewrite(harness: Harness): Record<string, unknown> {
  const payload: Record<string, unknown> = { model: "main" };
  harness.beforeRequest({ payload });
  return payload;
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
  expect(harness.messages).toEqual([
    "scope preset: local\nscope preset: local\n  id         target\n  main       next/next-main (force thinking: high)",
  ]);
  expect(rewrite(harness)).toEqual({
    model: "next-main",
    reasoning_effort: "high",
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
  expect(harness.messages).toEqual([
    "scope preset: local\nscope preset: local\n  id         target\n  main       next/next-main (force thinking: high)",
    "scope preset: codex\nscope preset: codex\n  id         target\n  main       old/old-main (force thinking: medium)",
  ]);
  expect(rewrite(harness)).toEqual({
    model: "old-main",
    reasoning_effort: "medium",
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
  const previous = structuredClone(
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
  expect(rewrite(harness)).toEqual({ model: "old-main" });
  expect(harness.messages).toEqual([
    'scope: ERROR — preset "noauth" no credentials resolved for noauth/noauth-main; scoped provider registration was not changed. Check the provider credentials.\nscope: previous preset "codex" restored; request rewriting remains on its targets.',
  ]);
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
        rewrite: { model: "old-main", reasoning_effort: "medium" },
        thinking: "medium",
      },
    },
    {
      preset: "local",
      expected: {
        name: "Local main model [S]",
        key: "next-key",
        rewrite: { model: "next-main", reasoning_effort: "high" },
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
    expect(rewrite(second)).toEqual(scenario.expected.rewrite);
    expect(second.ctx.thinkingLevel).toBe(scenario.expected.thinking);
    expect(processState()).toEqual({
      activePreset: scenario.preset,
      upgradedPreset: scenario.preset,
      rewriteDisabled: false,
    });
  }
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
  expect(harness.selectCalls).toEqual([
    {
      title: "Select scope:",
      options: ["codex", "noauth", "unavailable", "local"],
    },
  ]);
  expect(harness.messages).toEqual([
    "scope preset: local\nscope preset: local\n  id         target\n  main       next/next-main (force thinking: high)",
  ]);
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
  expect(rewrite(harness)).toEqual({
    model: "next-main",
    reasoning_effort: "high",
  });
});

test("cancelling the UI selector is a complete no-op", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  const beforeConfig = structuredClone(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );
  const beforeModel = { ...harness.ctx.model };
  const beforeThinking = harness.ctx.thinkingLevel;
  const beforeStatuses = [...harness.statuses];
  const beforeMessages = [...harness.messages];
  const beforeRewrite = rewrite(harness);
  const beforeProcess = {
    activePreset: (globalThis as Record<string, unknown>).activePreset,
    upgradedPreset: (globalThis as Record<string, unknown>).upgradedPreset,
    rewriteDisabled: (globalThis as Record<string, unknown>).rewriteDisabled,
  };

  await harness.command("", harness.ctx);

  expect(harness.selectCalls).toEqual([
    {
      title: "Select scope:",
      options: ["codex", "noauth", "unavailable", "local"],
    },
  ]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    beforeConfig,
  );
  expect(harness.ctx.model).toEqual(beforeModel);
  expect(harness.ctx.thinkingLevel).toBe(beforeThinking);
  expect(harness.statuses).toEqual(beforeStatuses);
  expect(harness.messages).toEqual(beforeMessages);
  expect(rewrite(harness)).toEqual(beforeRewrite);
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
  const beforeConfig = structuredClone(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );

  await harness.command("", harness.ctx);

  expect(harness.selectCalls).toEqual([
    {
      title: "Select scope:",
      options: ["codex", "noauth", "unavailable", "local"],
    },
  ]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    beforeConfig,
  );
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.messages).toEqual([
    'already on preset "codex"\nscope preset: codex\n  id         target\n  main       old/old-main',
  ]);
});

test("non-UI no-argument scope retains the table fallback", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key" },
    models: [target("old", "old-main", "Cloud main model")],
  });
  harness.ctx.hasUI = false;
  const beforeConfig = structuredClone(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );
  const beforeModel = { ...harness.ctx.model };
  const beforeThinking = harness.ctx.thinkingLevel;
  const beforeStatuses = [...harness.statuses];
  const beforeRewrite = rewrite(harness);

  await harness.command("", harness.ctx);

  expect(harness.selectCalls).toEqual([]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    beforeConfig,
  );
  expect(harness.ctx.model).toEqual(beforeModel);
  expect(harness.ctx.thinkingLevel).toBe(beforeThinking);
  expect(harness.messages).toEqual([
    "scope preset: codex\n  id         target\n  main       old/old-main",
  ]);
  expect(harness.statuses).toEqual(beforeStatuses);
  expect(rewrite(harness)).toEqual(beforeRewrite);
});

test("a selected failed switch rolls back like a direct argument", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", noauth: undefined },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("noauth", "noauth-main", "Unauthenticated main model"),
    ],
  });
  const previous = structuredClone(
    harness.registry.getRegisteredProviderConfig("scoped"),
  );
  harness.selection = "noauth";

  await harness.command("", harness.ctx);

  expect(harness.selectCalls).toEqual([
    {
      title: "Select scope:",
      options: ["codex", "noauth", "unavailable", "local"],
    },
  ]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(
    previous,
  );
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.ctx.thinkingLevel).toBe("medium");
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(rewrite(harness)).toEqual({ model: "old-main" });
  expect(harness.messages).toEqual([
    'scope: ERROR — preset "noauth" no credentials resolved for noauth/noauth-main; scoped provider registration was not changed. Check the provider credentials.\nscope: previous preset "codex" restored; request rewriting remains on its targets.',
  ]);
});

test("missing target auth preserves the previous scoped provider and rewrite table", async () => {
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
  expect(rewrite(harness)).toEqual({ model: "old-main" });
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.messages.at(-1)).toContain('previous preset "codex" restored');
});

test("an unresolvable target rolls back to the previous provider and rewrite table", async () => {
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
  expect(rewrite(harness)).toEqual({ model: "old-main" });
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.messages.at(-1)).toContain('previous preset "codex" restored');
});

test("a failed registry rollback disables rewriting and requires a restart", async () => {
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
  expect(rewrite(harness)).toEqual({ model: "main" });
  expect(harness.statuses).toEqual([{ key: "scope", value: "scope:codex" }]);
  expect(harness.messages.at(-1)).toContain("restart the session");
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
  expect(rewrite(harness)).toEqual({ model: "next-main" });

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
  expect(rewrite(harness)).toEqual({ model: "old-main" });

  harness.ctx.model = { provider: "old", id: "old-main" };
  await harness.command("local", harness.ctx);
  expect(harness.ctx.model).toEqual({ provider: "old", id: "old-main" });
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe(
    "next-key",
  );
});

test("rewrites scoped parent and child payloads to exact concrete model ids while leaving direct ids unchanged", async () => {
  const harness = await createHarness(markerPresets, {
    apiKeys: { old: "old-key" },
    models: markerModels(),
  });
  const parent = { model: "main" };
  const child = { model: "junior" };
  const direct = { model: "old-main" };

  harness.beforeRequest({ payload: parent });
  harness.beforeRequest({ payload: child });
  harness.beforeRequest({ payload: direct });

  expect(parent).toEqual({ model: "old-main" });
  expect(child).toEqual({ model: "old-junior", reasoning_effort: "high" });
  expect(direct).toEqual({ model: "old-main" });
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
    { codex: { main: { model: "old/old-main", thinking: "high" }, remap: {} } },
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
  expect(rewrite(harness)).toEqual({ model: "old-main" });

  harness.registry.apiKeys.set("next", "next-key");
  await harness.command("local", harness.ctx);
  await harness.summaryHandlers.session_before_compact[0](event, harness.ctx);

  expect(compactCalls).toHaveLength(2);
  expect(compactCalls[1][1]).toEqual(nextModel);
  expect(compactCalls[1][2]).toBe("next-summary-key");
  expect(rewrite(harness)).toEqual({
    model: "next-main",
    reasoning_effort: "high",
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
  const harness = await createHarness(selectorPresets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [oldModel, nextModel],
    requestAuth: {
      "old/old-main": async () => {
        authStarted();
        return pendingAuth;
      },
      "next/next-main": { ok: true, apiKey: "next-summary-key" },
    },
  });
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
  expect(authHarness.messages.at(-1)).toBe(
    "scope: ERROR — compaction with old/old-main failed: credential expired. Check the target model and credentials, then retry.",
  );

  authHarness.sendMessageFailure = new Error("message sink unavailable");
  await expect(
    authHarness.summaryHandlers.session_before_compact[0](
      { preparation: {}, signal },
      authHarness.ctx,
    ),
  ).resolves.toEqual({ cancel: true });
  expect(compactCalls).toEqual([]);

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
  expect(generationHarness.messages.at(-1)).toBe(
    "scope: ERROR — branch summary with old/old-main failed: non-retryable invalid request. Check the target model and credentials, then retry.",
  );
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
