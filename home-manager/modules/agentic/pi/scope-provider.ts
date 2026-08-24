/**
 * Registers a `scoped` pseudo-provider whose ids resolve per active preset to
 * concrete models from the `scopeProvider` settings table. Factory registers
 * stub entries so `scoped/<id>` resolves at startup; `session_start` refreshes
 * them with entries cloned from the live registry; `before_provider_request`
 * rewrites outgoing bodies to the target's bare id (and forces effort when the
 * preset entry sets `thinking`).
 *
 * Env:
 *  PI_SCOPE            active preset at launch (default "cloud")
 *  PI_SCOPE_LOG        path to append debug lines + one JSON line per payload
 *  PI_SCOPE_REWRITE=0  kill switch: disable the model rewrite (pass-through)
 */
import * as fs from "node:fs";
import * as path from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";

type ScopeEntry = { model: string; thinking?: string };
type ScopePreset = { main: ScopeEntry; remap: Record<string, ScopeEntry> };
type ScopeRegistration = { count: number; mainAvailable: boolean; failure?: string };
type ScopeSnapshot = {
  preset: string;
  entries: Record<string, ScopeEntry>;
  targets: Record<string, { provider: string; id: string }>;
  meta: Record<string, { api: string; thinkingFormat?: string; thinkingLevelMap?: Record<string, string | null> }>;
  activePreset?: string;
  upgradedPreset?: string;
  rewriteDisabled?: boolean;
  providerConfig?: any;
  selectedModel?: { provider: string; id: string };
  thinkingLevel?: string;
};

const SCOPE_IDS = ["main", "junior", "mid", "senior", "staff", "principal"];

// Stub entries so `scoped/<id>` resolves before session_start upgrades them
// from the live registry; upgrade failure fails loud (see session_start).
const STUB_MODEL = {
  reasoning: true,
  input: ["text"],
  contextWindow: 185000,
  maxTokens: 15000,
  samplingParams: { temperature: 1.0, top_p: 0.95, top_k: 20, presence_penalty: 0.0, repetition_penalty: 1.0 },
  thinkingLevelMap: { minimal: "low", low: "low", medium: "medium", high: "xhigh", xhigh: "xhigh", max: "xhigh" },
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
};

// Session ordinal tag: each session loads its own ExtensionRunner (fresh module
// state), so a child's post-rewrite payload is attributed even when the main
// session never sees the child's request.
let source;
{
  const g: any = globalThis;
  g.__PI_SCOPE_SEQ__ = (g.__PI_SCOPE_SEQ__ ?? 0) + 1;
  source = `s${g.__PI_SCOPE_SEQ__}`;
}

// Process-global active preset: every session re-imports this module (fresh
// `state`), so a child resolves scoped/<id> against the parent's live preset,
// not the env default.
const scopeProcess: { activePreset?: string; upgradedPreset?: string; rewriteDisabled?: boolean } = globalThis as any;
if (!scopeProcess.activePreset) scopeProcess.activePreset = process.env.PI_SCOPE ?? "cloud";

const state: {
  preset: string;
  entries: Record<string, ScopeEntry>;
  targets: Record<string, { provider: string; id: string }>;
  meta: Record<string, { api: string; thinkingFormat?: string; thinkingLevelMap?: Record<string, string | null> }>;
} = {
  preset: process.env.PI_SCOPE ?? "cloud",
  entries: {},
  targets: {},
  meta: {},
};

function debug(msg: string): void {
  const file = process.env.PI_SCOPE_LOG;
  if (file) fs.appendFileSync(file, `[${new Date().toISOString()}] ${msg}\n`);
}

function readScopeConfig(): Record<string, ScopePreset> {
  const file = path.join(getAgentDir(), "settings.json");
  const raw = JSON.parse(fs.readFileSync(file, "utf8")) as { scopeProvider?: Record<string, ScopePreset> };
  return raw.scopeProvider ?? {};
}

/** Point the process-global state at a preset's main+remap table. */
function applyPreset(name: string): boolean {
  const cfg = readScopeConfig();
  const preset = cfg[name];
  if (!preset) {
    debug(`applyPreset: preset "${name}" not found in scopeProvider (available: ${Object.keys(cfg).join(", ")})`);
    return false;
  }
  state.preset = name;
  state.entries = {};
  state.targets = {};

  // Registry-derived meta is rebuilt only by registerScope and shared
  // process-wide, so it must survive re-entry: child sessions re-run
  // applyPreset, and wiping it would drop the cloned thinkingFormat before a
  // child's first rewrite.

  const table: Array<[string, ScopeEntry]> = [["scoped/main", preset.main], ...Object.entries(preset.remap)];
  for (const [key, entry] of table) {
    const bare = key.split("/").pop() as string;
    const slash = entry.model.indexOf("/");
    if (!bare || slash < 0) {
      debug(`applyPreset: bad entry "${key}" -> "${entry.model}"`);
      continue;
    }
    state.entries[bare] = entry;
    state.targets[bare] = { provider: entry.model.slice(0, slash), id: entry.model.slice(slash + 1) };
  }
  debug(`applyPreset: active preset "${name}" (main -> ${preset.main.model})`);
  return true;
}

/** Register the stub entries so `scoped/<id>` resolves at startup. */
function registerScopeStubs(pi: any): void {
  pi.registerProvider("scoped", {
    name: "Scoped",
    baseUrl: "http://deskapp.n3x.net:15000/v1",
    api: "openai-completions",
    apiKey: "local",
    models: SCOPE_IDS.map((id) => ({
      id,
      name: `scoped/${id} (preset stub, upgraded at session start)`,
      ...STUB_MODEL,
    })),
  });
  debug("factory: registered scoped stubs");
}

/**
 * Clone each scoped id from its target model in the live registry and register
 * the `scoped` provider. Re-registering replaces the provider's model list.
 */
async function registerScope(pi: any, ctx: any): Promise<ScopeRegistration> {
  const meta: typeof state.meta = {};
  const models: any[] = [];
  let mainAvailable = false;
  for (const id of SCOPE_IDS) {
    const entry = state.entries[id];
    const target = state.targets[id];
    if (!entry || !target) continue;
    const m = ctx.modelRegistry.find(target.provider, target.id);
    if (!m) {
      debug(`registerScope: target ${target.provider}/${target.id} not found in registry (skipping scoped/${id})`);
      continue;
    }
    if (id === "main") mainAvailable = true;
    meta[id] = { api: m.api, thinkingFormat: m.compat?.thinkingFormat, thinkingLevelMap: m.thinkingLevelMap };
    debug(`registerScope: scoped/${id} <- ${m.provider}/${m.id} api=${m.api} thinkingFormat=${m.compat?.thinkingFormat ?? "<none>"} baseUrl=${m.baseUrl} tlm=${JSON.stringify(m.thinkingLevelMap ?? null)}`);

    models.push({
      id,
      name: `${m.name} [S]`,
      api: m.api,
      baseUrl: m.baseUrl,
      reasoning: m.reasoning,
      thinkingLevelMap: m.thinkingLevelMap,
      input: m.input,
      cost: m.cost,
      contextWindow: m.contextWindow,
      maxTokens: m.maxTokens,
      samplingParams: m.samplingParams,
      compat: m.compat,
    });
  }
  if (models.length === 0) {
    debug("registerScope: no resolvable targets, not registering");
    return { count: 0, mainAvailable };
  }
  if (!mainAvailable) {
    debug("registerScope: scoped/main target is not resolvable, not registering");
    return { count: 0, mainAvailable };
  }
  const provider = state.targets.main;
  let apiKey: string | undefined;
  try {
    apiKey = await ctx.modelRegistry.getApiKeyForProvider(provider.provider);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return {
      count: 0,
      mainAvailable,
      failure: `could not resolve credentials for ${provider.provider}/${provider.id}: ${detail}`,
    };
  }
  if (!apiKey) {
    return {
      count: 0,
      mainAvailable,
      failure: `no credentials resolved for ${provider.provider}/${provider.id}`,
    };
  }

  debug(`registerScope: preset="${state.preset}" models=[${models.map((x) => x.id).join(",")}] targetProvider=${provider.provider} apiKey=${apiKey.slice(0, 12)}...`);

  pi.registerProvider("scoped", { name: "Scoped", apiKey, models });
  state.meta = meta;

  return { count: models.length, mainAvailable };
}

/** Capture all mutable scope state before a provider replacement. */
function snapshotScope(ctx: any): ScopeSnapshot {
  const model = ctx.model;

  return {
    preset: state.preset,
    entries: { ...state.entries },
    targets: { ...state.targets },
    meta: { ...state.meta },
    activePreset: scopeProcess.activePreset,
    upgradedPreset: scopeProcess.upgradedPreset,
    rewriteDisabled: scopeProcess.rewriteDisabled,
    providerConfig: ctx.modelRegistry.getRegisteredProviderConfig("scoped"),
    selectedModel: model && typeof model.provider === "string" && typeof model.id === "string"
      ? { provider: model.provider, id: model.id }
      : undefined,
    thinkingLevel: typeof ctx.thinkingLevel === "string" ? ctx.thinkingLevel : undefined,
  };
}

/** Disable model rewriting when the provider registry cannot be restored safely. */
function disableScopeRewrites(): void {
  state.entries = {};
  state.targets = {};
  state.meta = {};
  scopeProcess.rewriteDisabled = true;
}

/** Restore the process and registry to a previously usable scope. */
function restoreScope(pi: any, ctx: any, snapshot: ScopeSnapshot): string | undefined {
  try {
    if (snapshot.providerConfig) {
      pi.registerProvider("scoped", snapshot.providerConfig);
    } else {
      ctx.modelRegistry.unregisterProvider("scoped");
    }

    const restoredMain = ctx.modelRegistry.find("scoped", "main");
    if (snapshot.providerConfig ? !restoredMain : restoredMain) {
      throw new Error("the previous scoped provider did not restore its expected scoped/main entry");
    }
    if (snapshot.selectedModel?.provider === "scoped") {
      const current = ctx.model;
      if (!current || current.provider !== snapshot.selectedModel.provider || current.id !== snapshot.selectedModel.id) {
        throw new Error(`the previous selected model ${snapshot.selectedModel.provider}/${snapshot.selectedModel.id} could not be restored`);
      }
    }
    if (snapshot.thinkingLevel !== undefined) pi.setThinkingLevel(snapshot.thinkingLevel);
  } catch (error) {
    disableScopeRewrites();
    const detail = error instanceof Error ? error.message : String(error);
    return `provider registry restoration failed: ${detail}; scoped request rewriting was disabled and the session must be restarted`;
  }

  state.preset = snapshot.preset;
  state.entries = snapshot.entries;
  state.targets = snapshot.targets;
  state.meta = snapshot.meta;
  scopeProcess.activePreset = snapshot.activePreset;
  scopeProcess.upgradedPreset = snapshot.upgradedPreset;
  scopeProcess.rewriteDisabled = snapshot.rewriteDisabled;
  return undefined;
}

/** Map a forced effort level through the target's thinkingLevelMap (passthrough when unmapped). */
function forcedEffort(id: string, level: string): string {
  const tlm = state.meta[id]?.thinkingLevelMap;
  const mapped = tlm?.[level];
  return mapped === undefined || mapped === null ? level : mapped;
}

/**
 * Field-aware effort forcing on the outgoing request body:
 * chat-template targets carry effort in `chat_template_kwargs`, codex
 * responses use `body.reasoning.effort`, other openai-completions use a
 * top-level `reasoning_effort`.
 */
function forceEffort(id: string, payload: any, level: string): void {
  const meta = state.meta[id];
  const effort = forcedEffort(id, level);
  debug(`forceEffort[${source}]: id=${id} level=${level} effort=${effort} meta=${JSON.stringify(meta ?? null)}`);
  if (meta?.thinkingFormat === "chat-template" || meta?.thinkingFormat === "qwen-chat-template") {
    payload.chat_template_kwargs = { ...payload.chat_template_kwargs, enable_thinking: true, reasoning_effort: effort };
  } else if (meta?.api === "openai-codex-responses" || meta?.api === "openai-responses") {
    payload.reasoning = { ...payload.reasoning, effort };
  } else {
    payload.reasoning_effort = effort;
  }
}

/**
 * Verify that provider re-registration refreshed the selected scoped/main
 * entry, then apply the preset's configured thinking level. Concrete models
 * are intentionally not changed.
 */
async function refreshMainIfScopedMain(pi: any, ctx: any, label: string, report = true): Promise<boolean> {
  const cur = ctx.model;
  if (!cur || cur.provider !== "scoped" || cur.id !== "main") {
    debug(`${label}: session model ${cur ? cur.provider + "/" + cur.id : "none"} is not scoped/main, left untouched`);
    return true;
  }

  const entry = state.entries.main;
  const target = state.targets.main;
  // registerProvider refreshes the session's current model by its stable
  // provider/id identity; changing it to the concrete target would disable
  // future preset refreshes.
  const refreshed = ctx.modelRegistry.find("scoped", "main");
  if (!refreshed) {
    const msg = `scope: ERROR — session is on scoped/main but the refreshed scoped/main entry is unavailable (target ${target ? `${target.provider}/${target.id}` : "<unset>"}); scoped/main requests will fail. Check the scopeProvider settings.`;
    debug(`${label}: ${msg}`);
    if (report) pi.sendMessage({ customType: "scoped", content: msg, display: true });
    return false;
  }

  if (entry?.thinking) pi.setThinkingLevel(entry.thinking);
  debug(`${label}: refreshed scoped/main -> ${target ? `${target.provider}/${target.id}` : "<unset>"} thinking=${entry?.thinking ?? "unchanged"}`);
  return true;
}

/** Publish the compact Powerline status for the active preset. */
function publishScopeStatus(ctx: any): void {
  ctx.ui.setStatus("scope", `scope:${state.preset}`);
}

/** Show the active preset and its remap table as a session message. */
function scopeTable(): string {
  const lines = [`scope preset: ${state.preset}`, "  " + "id".padEnd(11) + "target"];
  for (const id of SCOPE_IDS) {
    const entry = state.entries[id];
    if (!entry) continue;
    lines.push(`  ${id.padEnd(11)}${entry.model}${entry.thinking ? ` (force thinking: ${entry.thinking})` : ""}`);
  }
  return lines.join("\n");
}

export default function scopeProvider(pi: any): void {
  debug(`load: preset=${state.preset} activePreset=${scopeProcess.activePreset} rewrite=${process.env.PI_SCOPE_REWRITE !== "0"} log=${process.env.PI_SCOPE_LOG ?? "off"}`);

  // Re-imports start with an empty table: (re)apply the live process preset so
  // the rewrite table matches what the process serves, and a re-imported
  // sub-agent session inherits the parent's current preset.
  if (scopeProcess.rewriteDisabled) {
    disableScopeRewrites();
  } else if (Object.keys(state.entries).length === 0) {
    applyPreset(scopeProcess.activePreset);
  }

  // Register stubs only until a session's upgrade has replaced them in the
  // shared runtime; a later (child) session's factory must not clobber the
  // upgraded entries (tracked process-wide; each re-import has fresh state).
  if (!scopeProcess.rewriteDisabled && !scopeProcess.upgradedPreset) {
    registerScopeStubs(pi);
  }

  pi.on("session_start", async (_event: any, ctx: any) => {
    if (scopeProcess.rewriteDisabled) return;

    const registration = await registerScope(pi, ctx);

    if (registration.count === 0 || !registration.mainAvailable) {
      const available = Object.keys(readScopeConfig()).join(", ") || "<none>";
      const msg = registration.failure
        ? `scope: ERROR — preset "${state.preset}" ${registration.failure}; scoped provider registration was not changed. Check the provider credentials and restart the session.`
        : !registration.mainAvailable
          ? `scope: ERROR — preset "${state.preset}" has no resolvable scoped/main target; scoped/main requests will fail. Check the scopeProvider settings and models.`
          : `scope: ERROR — preset "${state.preset}" has no resolvable targets in the model registry (available presets: ${available}); scoped/* model requests will fail. Check the scopeProvider settings and models.`;
      debug(`session_start: ${msg}`);
      pi.sendMessage({ customType: "scoped", content: msg, display: true });

      return;
    }

    if (!(await refreshMainIfScopedMain(pi, ctx, "session_start"))) return;
    // Later re-imports must not re-register factory stubs over the refreshed
    // provider entries shared by this process.
    scopeProcess.upgradedPreset = state.preset;
    publishScopeStatus(ctx);
  });

  pi.on("before_provider_request", (event: any) => {
    const payload = event.payload as any;

    if (payload && typeof payload === "object" && typeof payload.model === "string") {
      const entry = state.entries[payload.model];

      if (entry && !scopeProcess.rewriteDisabled && process.env.PI_SCOPE_REWRITE !== "0") {
        const target = state.targets[payload.model];
        const from = payload.model;

        payload.model = target.id;

        let appliedEffort = undefined;

        if (entry.thinking) {
          appliedEffort = forcedEffort(from, entry.thinking);
          forceEffort(from, payload, entry.thinking);
        }

        debug(`rewrite[${source}]: scoped/${from} -> ${payload.model} (preset=${state.preset}${entry.thinking ? `, forced thinking=${entry.thinking} (effort=${appliedEffort})` : ""}) chat_template_kwargs=${JSON.stringify(payload.chat_template_kwargs ?? null)} reasoning=${JSON.stringify(payload.reasoning ?? null)} reasoning_effort=${JSON.stringify(payload.reasoning_effort ?? null)}`);
      } else if (entry) {
        debug(`rewrite[${source}] disabled: leaving scoped/${payload.model} untouched`);
      }
    }

    const logFile = process.env.PI_SCOPE_LOG;

    if (logFile && payload && typeof payload === "object") {
      fs.appendFileSync(logFile, JSON.stringify({ ts: Date.now(), src: source, body: payload }) + "\n");
    }
  });

  const switchScope = async (name: string, ctx: any): Promise<void> => {
    if (scopeProcess.rewriteDisabled) {
      pi.sendMessage({ customType: "scoped", content: "scope: ERROR — scoped request rewriting is disabled because provider rollback failed. Restart the session before switching presets.", display: true });

      return;
    }

    if (name === state.preset) {
      pi.sendMessage({ customType: "scoped", content: `already on preset "${name}"\n${scopeTable()}`, display: true });

      return;
    }

    const previous = snapshotScope(ctx);

    try {
      if (!applyPreset(name)) {
        pi.sendMessage({ customType: "scoped", content: `unknown preset "${name}" (available: ${Object.keys(readScopeConfig()).join(", ")})`, display: true });

        return;
      }

      const registration = await registerScope(pi, ctx);

      if (registration.count === 0 || !registration.mainAvailable) {
        const available = Object.keys(readScopeConfig()).join(", ") || "<none>";
        const msg = registration.failure
          ? `scope: ERROR — preset "${name}" ${registration.failure}; scoped provider registration was not changed. Check the provider credentials.`
          : !registration.mainAvailable
            ? `scope: ERROR — preset "${name}" has no resolvable scoped/main target; scoped/main requests will fail. Check the scopeProvider settings and models.`
            : `scope: ERROR — preset "${name}" has no resolvable targets in the model registry (available presets: ${available}); scoped/* model requests will fail. Check the scopeProvider settings and models.`;
        throw new Error(msg);
      }

      if (!(await refreshMainIfScopedMain(pi, ctx, `/scope ${name}`, false))) {
        throw new Error(`scope: ERROR — preset "${name}" could not refresh the selected scoped/main entry; scoped/main requests will fail. Check the scopeProvider settings and models.`);
      }

      // Publish process-wide after the alias refresh succeeds so re-importing
      // sub-agent sessions only observes a usable preset.
      scopeProcess.activePreset = name;
      scopeProcess.upgradedPreset = state.preset;
      publishScopeStatus(ctx);
    } catch (error) {
      const failure = error instanceof Error ? error.message : String(error);
      const rollbackFailure = restoreScope(pi, ctx, previous);
      const content = rollbackFailure
        ? `scope: ERROR — switching to preset "${name}" failed: ${failure}; rollback failed: ${rollbackFailure}. Check the scopeProvider settings and restart the session.`
        : `${failure}\nscope: previous preset "${previous.preset}" restored; request rewriting remains on its targets.`;
      debug(`/scope ${name}: ${content}`);
      pi.sendMessage({ customType: "scoped", content, display: true });
      return;
    }

    pi.sendMessage({ customType: "scoped", content: `scope preset: ${name}\n${scopeTable()}`, display: true });
  };

  pi.registerCommand("scope", {
    description: "Select a preset with /scope, or switch directly with /scope <preset>",
    handler: async (args: string, ctx: any) => {
      const name = args.trim();

      if (!name) {
        if (!ctx.hasUI) {
          pi.sendMessage({ customType: "scoped", content: scopeTable(), display: true });
          return;
        }

        const selected = await ctx.ui.select("Select scope:", Object.keys(readScopeConfig()));
        if (selected === undefined) return;
        await switchScope(selected, ctx);
        return;
      }

      await switchScope(name, ctx);
    },
  });
}
