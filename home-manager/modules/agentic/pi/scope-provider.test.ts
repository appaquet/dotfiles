import { afterEach, beforeEach, expect, mock, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

type ProviderConfig = { apiKey?: string; models?: Model[]; [key: string]: unknown };
type Model = {
  provider: string;
  id: string;
  name: string;
  api: string;
  baseUrl: string;
  reasoning: boolean;
  input: string[];
  cost: { input: number; output: number; cacheRead: number; cacheWrite: number };
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
type StatusEvent = { key: string; value: string };

type TestContext = {
  model: { provider: string; id: string };
  thinkingLevel: string;
  hasUI: boolean;
  modelRegistry: TestRegistry;
  ui: {
    setStatus: (key: string, value: string) => void;
    select: (title: string, options: string[]) => Promise<string | undefined>;
  };
};

class TestRegistry {
  readonly configs = new Map<string, ProviderConfig>();
  readonly models = new Map<string, Model>();
  readonly apiKeys = new Map<string, string | undefined>();

  find(provider: string, id: string): Model | undefined {
    return this.models.get(`${provider}/${id}`);
  }

  async getApiKeyForProvider(provider: string): Promise<string | undefined> {
    return this.apiKeys.get(provider);
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
    if (provider !== "scoped") throw new Error(`unexpected provider ${provider}`);
    this.configs.delete(provider);
    for (const key of [...this.models.keys()]) {
      if (key.startsWith(`${provider}/`)) this.models.delete(key);
    }
  }
}

type Harness = {
  registry: TestRegistry;
  factoryConfig?: ProviderConfig;
  ctx: TestContext;
  command: ScopeCommand;
  commandDescription: string;
  shortcuts: Array<{ key: string; description: string; handler: ScopeShortcut }>;
  beforeRequest: ScopeHandler;
  messages: string[];
  statuses: StatusEvent[];
  selectCalls: Array<{ title: string; options: string[] }>;
  selection?: string;
  setStatusFailure?: Error;
  restoreFailure: boolean;
};

let agentDir = "";
let testDir = "";

mock.module("@earendil-works/pi-coding-agent", () => ({
  getAgentDir: () => agentDir,
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
});

afterEach(() => {
  rmSync(testDir, { recursive: true, force: true });
});

async function createHarness(
  config: ScopeConfig,
  options: { apiKeys?: Record<string, string | undefined>; models?: Model[] } = {},
): Promise<Harness> {
  writeFileSync(join(testDir, "settings.json"), JSON.stringify({ scopeProvider: config }));

  const registry = new TestRegistry();
  for (const model of options.models ?? []) registry.models.set(`${model.provider}/${model.id}`, model);
  for (const [provider, apiKey] of Object.entries(options.apiKeys ?? {})) registry.apiKeys.set(provider, apiKey);

  const messages: string[] = [];
  const statuses: StatusEvent[] = [];
  const selectCalls: Array<{ title: string; options: string[] }> = [];
  let command: ScopeCommand | undefined;
  let beforeRequest: ScopeHandler | undefined;
  const shortcuts: Array<{ key: string; description: string; handler: ScopeShortcut }> = [];
  const harness: Harness = {
    registry,
    ctx: {
      model: { provider: "scoped", id: "main" },
      thinkingLevel: "medium",
      hasUI: true,
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
    messages,
    statuses,
    selectCalls,
    restoreFailure: false,
  };
  const pi = {
    registerProvider: (provider: string, registration: ProviderConfig) => {
      if (provider !== "scoped") throw new Error(`unexpected provider ${provider}`);
      if (harness.restoreFailure && registration.apiKey === "old-key") throw new Error("restore unavailable");
      registry.setScoped(registration);
    },
    unregisterProvider: (provider: string) => registry.unregisterProvider(provider),
    on: (event: string, handler: ScopeHandler | ((event: unknown, ctx: TestContext) => Promise<void>)) => {
      if (event === "before_provider_request") beforeRequest = handler as ScopeHandler;
      if (event === "session_start") (harness as Harness & { sessionStart?: (event: unknown, ctx: TestContext) => Promise<void> }).sessionStart = handler as (event: unknown, ctx: TestContext) => Promise<void>;
    },
    registerCommand: (_name: string, registration: { description: string; handler: ScopeCommand }) => {
      command = registration.handler;
      harness.commandDescription = registration.description;
    },
    registerShortcut: (key: string, registration: { description: string; handler: ScopeShortcut }) => {
      shortcuts.push({ key, ...registration });
    },
    sendMessage: ({ content }: { content: string }) => messages.push(content),
    setThinkingLevel: (level: string) => {
      harness.ctx.thinkingLevel = level;
    },
  };

  const module = await import(`./scope-provider.ts?${crypto.randomUUID()}`);
  module.default(pi);
  harness.factoryConfig = structuredClone(registry.getRegisteredProviderConfig("scoped"));
  const sessionStart = (harness as Harness & { sessionStart?: (event: unknown, ctx: TestContext) => Promise<void> }).sessionStart;
  if (!sessionStart || !command || !beforeRequest) throw new Error("scope extension did not register its handlers");
  harness.command = command;
  harness.beforeRequest = beforeRequest;
  await sessionStart({}, harness.ctx);
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
      "scoped/junior": { model: "old/old-junior" },
      "scoped/mid": { model: "old/old-main" },
    },
  },
  local: {
    main: { model: "next/next-main" },
    remap: {
      "scoped/junior": { model: "next/next-junior" },
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
    (harness.registry.getRegisteredProviderConfig("scoped")?.models ?? []).map((model) => [model.id, model.name]),
  );
}

function rewrite(harness: Harness): Record<string, unknown> {
  const payload: Record<string, unknown> = { model: "main" };
  harness.beforeRequest({ payload });
  return payload;
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

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("next-key");
  expect(harness.registry.find("scoped", "main")?.name).toBe("Local main model [S]");
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
  expect(rewrite(harness)).toEqual({ model: "next-main", reasoning_effort: "high" });

  await cycle(harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("old-key");
  expect(harness.registry.find("scoped", "main")?.name).toBe("Cloud main model [S]");
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
  expect(rewrite(harness)).toEqual({ model: "old-main", reasoning_effort: "medium" });
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
  const previous = structuredClone(harness.registry.getRegisteredProviderConfig("scoped"));

  await cycle(harness.ctx);

  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(previous);
  expect(harness.registry.find("scoped", "main")?.name).toBe("Cloud main model [S]");
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

  expect(harness.commandDescription).toBe("Select a preset with /scope, or switch directly with /scope <preset>");
  expect(harness.selectCalls).toEqual([{
    title: "Select scope:",
    options: ["codex", "noauth", "unavailable", "local"],
  }]);
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
  expect(harness.registry.find("scoped", "main")).toMatchObject({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")?.name).toBe("Local main model [S]");
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("next-key");
  expect(rewrite(harness)).toEqual({ model: "next-main", reasoning_effort: "high" });
});

test("cancelling the UI selector is a complete no-op", async () => {
  const harness = await createHarness(presets, {
    apiKeys: { old: "old-key", next: "next-key" },
    models: [
      target("old", "old-main", "Cloud main model"),
      target("next", "next-main", "Local main model"),
    ],
  });
  const beforeConfig = structuredClone(harness.registry.getRegisteredProviderConfig("scoped"));
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

  expect(harness.selectCalls).toEqual([{
    title: "Select scope:",
    options: ["codex", "noauth", "unavailable", "local"],
  }]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(beforeConfig);
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
  const beforeConfig = structuredClone(harness.registry.getRegisteredProviderConfig("scoped"));

  await harness.command("", harness.ctx);

  expect(harness.selectCalls).toEqual([{
    title: "Select scope:",
    options: ["codex", "noauth", "unavailable", "local"],
  }]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(beforeConfig);
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
  const beforeConfig = structuredClone(harness.registry.getRegisteredProviderConfig("scoped"));
  const beforeModel = { ...harness.ctx.model };
  const beforeThinking = harness.ctx.thinkingLevel;
  const beforeStatuses = [...harness.statuses];
  const beforeRewrite = rewrite(harness);

  await harness.command("", harness.ctx);

  expect(harness.selectCalls).toEqual([]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(beforeConfig);
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
  const previous = structuredClone(harness.registry.getRegisteredProviderConfig("scoped"));
  harness.selection = "noauth";

  await harness.command("", harness.ctx);

  expect(harness.selectCalls).toEqual([{
    title: "Select scope:",
    options: ["codex", "noauth", "unavailable", "local"],
  }]);
  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(previous);
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

  expect(harness.registry.getRegisteredProviderConfig("scoped")).toEqual(previous);
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("old-key");
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

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("old-key");
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

  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("next-key");
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

  expect(harness.registry.find("scoped", "main")).toMatchObject({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")?.name).toBe("Cloud main model [S]");

  await harness.command("local", harness.ctx);
  expect(harness.statuses).toEqual([
    { key: "scope", value: "scope:codex" },
    { key: "scope", value: "scope:local" },
  ]);
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")).toMatchObject({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")?.name).toBe("Local main model [S]");
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("next-key");
  expect(rewrite(harness)).toEqual({ model: "next-main" });

  await harness.command("codex", harness.ctx);
  expect(harness.statuses).toEqual([
    { key: "scope", value: "scope:codex" },
    { key: "scope", value: "scope:local" },
    { key: "scope", value: "scope:codex" },
  ]);
  expect(harness.ctx.model).toEqual({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")).toMatchObject({ provider: "scoped", id: "main" });
  expect(harness.registry.find("scoped", "main")?.name).toBe("Cloud main model [S]");
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("old-key");
  expect(rewrite(harness)).toEqual({ model: "old-main" });

  harness.ctx.model = { provider: "old", id: "old-main" };
  await harness.command("local", harness.ctx);
  expect(harness.ctx.model).toEqual({ provider: "old", id: "old-main" });
  expect(harness.registry.getRegisteredProviderConfig("scoped")?.apiKey).toBe("next-key");
});
