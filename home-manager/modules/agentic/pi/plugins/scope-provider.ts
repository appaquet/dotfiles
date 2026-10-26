/**
 * Registers a `scoped` pseudo-provider whose ids resolve per active preset to
 * concrete models from the `scopeProvider` settings table. Extension
 * initialization registers stub entries in each model registry so
 * `scoped/<id>` resolves at startup; `session_start` refreshes them with
 * entries cloned from the live registry. Alias resolution happens at the
 * provider layer: the registered `streamSimple` hook delegates every scoped
 * completion (agent loop, raw `ModelRegistry.complete`, summaries) to the
 * concrete target provider, so no payload rewriting is needed.
 *
 * /tree branch summaries route to a dedicated per-preset target
 * (`scoped/summary`), independent of the active work model. Compaction uses
 * the same target only when enabled via PI_SCOPE_SUMMARY_COMPACTION; by
 * default it yields to the session's cached-compaction extension (or Pi's
 * native path), which summarizes warm sessions through the already-cached
 * work-model prompt.
 *
 *
 * The built-in `none` scope needs no scopeProvider config. In `none` scope
 * every alias resolves per request to the last concrete (non-scoped) model
 * selected in the top-level session, recorded process-wide on model_select;
 * the target's credentials are resolved per request. Compaction and /tree
 * branch summaries follow the same model.
 * Env:
 *  PI_SCOPE            active preset at launch (default "go"); the built-in
 *                      "none" scope needs no scopeProvider entry
 *  PI_SCOPE_LOG        path to append debug lines
 *  PI_SCOPE_REWRITE=0  kill switch: disable alias resolution (pass-through)
 *  PI_SCOPE_SUMMARY_COMPACTION=1  enable dedicated-summary-model compaction
 *                      (off by default; cached-compaction covers warm sessions)
 */
import * as fs from "node:fs";
import * as path from "node:path";
import {
  compact,
  generateBranchSummary,
  getAgentDir,
  SettingsManager,
} from "@earendil-works/pi-coding-agent";
import { getApiProvider } from "@earendil-works/pi-ai/compat";
import { Text } from "@earendil-works/pi-tui";
import {
  filterFuzzyItems,
  selectFuzzyItem,
  type FuzzySelectorItem,
} from "../lib/fuzzy-selector.ts";

type SummaryThinkingLevel = NonNullable<Parameters<typeof compact>[6]>;
type ScopeEntry = { model: string; thinking?: SummaryThinkingLevel };
/** Optional instruction prompt pair injected into the model context for a preset. */
type ScopePrompt = { enable?: string; disable?: string };
type ScopePreset = {
  main: ScopeEntry;
  remap: Record<string, ScopeEntry>;
  prompt?: ScopePrompt;
};
type ScopeMapping = {
  preset: string;
  entries: Record<string, ScopeEntry>;
  targets: Record<string, { provider: string; id: string }>;
};
/** Request credentials resolved for one concrete target provider. */
type TargetAuth = {
  apiKey?: string;
  headers?: Record<string, string>;
  baseUrl?: string;
  env?: Record<string, string>;
};
type ScopeRegistration = {
  count: number;
  mainAvailable: boolean;
  summaryAvailable: boolean;
  failure?: string;
  concreteModels?: Record<string, any>;
  targetAuth?: Record<string, TargetAuth>;
  providerConfig?: any;
};
type ScopedSummaryTarget = {
  alias: string;
  entry: ScopeEntry;
  target: { provider: string; id: string };
  model: any;
  thinkingLevel: SummaryThinkingLevel;
};
type ScopeSnapshot = {
  preset: string;
  entries: Record<string, ScopeEntry>;
  targets: Record<string, { provider: string; id: string }>;
  concreteModels: Record<string, any>;
  targetAuth: Record<string, TargetAuth>;
  activePreset?: string;
  upgradedPreset?: string;
  rewriteDisabled?: boolean;
  providerConfig?: any;
  selectedModel?: { provider: string; id: string };
  thinkingLevel?: string;
};

const SCOPE_IDS = ["main", "junior", "mid", "senior", "staff", "principal", "reviewer"];

// Reserved internal alias for /tree branch summaries and opt-in context compaction.
// It is resolved and validated per preset like a work alias, but it is never
// added to the selectable work-model list, so it stays hidden from normal
// model selection. Summary events resolve this alias instead of the active
// work alias, so summarization is independent of the selected scoped model.
const SUMMARY_ALIAS = "summary";

// Built-in scope that resolves every alias to the user's manually selected
// model; available with or without any scopeProvider configuration.
const NONE_SCOPE = "none";
const SCOPE_STATE_ENTRY = "scope-provider-state";
const SCOPE_PROMPT_ENTRY = "scope-prompt";

// Stub entries so `scoped/<id>` resolves before session_start upgrades them
// from the live registry; upgrade failure fails loud (see session_start).
// Placeholder endpoint for scoped provider configs that have no static
// targets: the streamSimple hook intercepts every request before any HTTP
// happens, and the real registry requires a baseUrl on custom providers.
const STUB_BASE_URL = "http://deskapp.n3x.net:15000/v1";
const STUB_MODEL = {
  reasoning: true,
  input: ["text"],
  contextWindow: 185000,
  maxTokens: 15000,
  samplingParams: {
    temperature: 1.0,
    top_p: 0.95,
    top_k: 20,
    presence_penalty: 0.0,
    repetition_penalty: 1.0,
  },
  thinkingLevelMap: {
    minimal: "low",
    low: "low",
    medium: "medium",
    high: "xhigh",
    xhigh: "xhigh",
    max: "xhigh",
  },
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
};

// Session ordinal tag: each session loads its own ExtensionRunner (fresh module
// state), so a child's scoped completions are attributed even when the main
// session never sees the child's request.
const source = (() => {
  const g: any = globalThis;
  g.__PI_SCOPE_SEQ__ = (g.__PI_SCOPE_SEQ__ ?? 0) + 1;
  return `s${g.__PI_SCOPE_SEQ__}`;
})();

// Process-global active preset: every session re-imports this module (fresh
// `state`), so a child resolves scoped/<id> against the parent's live preset,
// not the env default.
const scopeProcess: {
  activePreset?: string;
  upgradedPreset?: string;
  rewriteDisabled?: boolean;
  followModel?: { provider: string; id: string };
} = globalThis as any;
if (!scopeProcess.activePreset)
  scopeProcess.activePreset = process.env.PI_SCOPE ?? "go";

// Per-session model registry used by the streamSimple hook: set on
// session_start so the hook resolves live target lookups against the registry
// its own session serves.
let scopeRegistry: any = undefined;

// Per-session manager used by the provider hook, which receives no
// ExtensionContext. session_start binds each extension runtime to its session.
let scopeSessionManager: any = undefined;

const state: ScopeMapping & {
  concreteModels: Record<string, any>;
  targetAuth: Record<string, TargetAuth>;
} = {
  preset: process.env.PI_SCOPE ?? "go",
  entries: {},
  targets: {},
  concreteModels: {},
  targetAuth: {},
};

// Prompt injection state for this session: the preset whose enable text the
// transcript holds, and the prompt armed for the next agent turn.
let activeEnablePreset: string | undefined;
let pendingScopePrompt:
  | { kind: "transition"; leaving: string; entering: string }
  | { kind: "active" }
  | undefined;

function debug(msg: string): void {
  const file = process.env.PI_SCOPE_LOG;
  if (file) fs.appendFileSync(file, `[${new Date().toISOString()}] ${msg}\n`);
}

/** The live conversation's session id, or undefined before session startup. */
function conversationSessionId(): string | undefined {
  return scopeSessionManager?.getSessionId?.() ?? undefined;
}

/**
 * Add semantic session identity to a delegated scoped request.
 *
 * Provider adapters own any wire representation. Caller identity remains
 * authoritative, and request options are copied only when an id is added.
 */
function withConversationSessionId(options: any): any {
  if (options?.sessionId !== undefined) return options;
  const sessionId = conversationSessionId();
  return sessionId ? { ...options, sessionId } : options;
}

function readScopeConfig(): Record<string, ScopePreset> {
  const file = path.join(getAgentDir(), "settings.json");
  const raw = JSON.parse(fs.readFileSync(file, "utf8")) as {
    scopeProvider?: Record<string, ScopePreset>;
  };
  return raw.scopeProvider ?? {};
}

/** Trimmed prompt text configured for a preset, or undefined when unusable. */
function scopePromptText(
  preset: string,
  kind: keyof ScopePrompt,
): string | undefined {
  // The built-in none scope shadows any user preset of the same name.
  if (preset === NONE_SCOPE) return undefined;
  const value = readScopeConfig()[preset]?.prompt?.[kind];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : undefined;
}

/** Find the newest persisted scope preset that remains configured. */
export function findSavedScopePreset(
  entries: readonly unknown[],
  presets: Record<string, ScopePreset>,
): string | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index] as any;
    if (
      entry?.type === "custom" &&
      entry.customType === SCOPE_STATE_ENTRY &&
      typeof entry.data?.preset === "string" &&
      (entry.data.preset === NONE_SCOPE || presets[entry.data.preset])
    )
      return entry.data.preset;
  }
  return undefined;
}

/** Build a preset mapping without publishing it as committed scope state. */
function buildPreset(name: string): ScopeMapping | undefined {
  if (name === NONE_SCOPE) {
    // Built-in scope: no config entry, no static targets.
    return { preset: NONE_SCOPE, entries: {}, targets: {} };
  }
  const cfg = readScopeConfig();
  const preset = cfg[name];
  if (!preset) {
    debug(
      `buildPreset: preset "${name}" not found in scopeProvider (available: ${Object.keys(cfg).join(", ")})`,
    );
    return undefined;
  }

  const mapping: ScopeMapping = { preset: name, entries: {}, targets: {} };
  const table: Array<[string, ScopeEntry]> = [
    ["scoped/main", preset.main],
    ...Object.entries(preset.remap),
  ];
  for (const [key, entry] of table) {
    const bare = key.split("/").pop() as string;
    const slash = entry.model.indexOf("/");
    if (!bare || slash < 0) {
      debug(`buildPreset: bad entry "${key}" -> "${entry.model}"`);
      continue;
    }
    mapping.entries[bare] = entry;
    mapping.targets[bare] = {
      provider: entry.model.slice(0, slash),
      id: entry.model.slice(slash + 1),
    };
  }
  debug(
    `buildPreset: resolved preset "${name}" (main -> ${preset.main.model})`,
  );
  return mapping;
}

/** Point state at a preset during initial extension setup. */
function applyPreset(name: string): boolean {
  const mapping = buildPreset(name);
  if (!mapping) return false;
  state.preset = mapping.preset;
  state.entries = mapping.entries;
  state.targets = mapping.targets;
  return true;
}

/**
 * Provider-layer alias resolution: delegate a scoped model completion to the
 * concrete target provider so every completion path (agent loop, raw
 * ModelRegistry.complete, summaries) reaches the target's id and endpoint
 * instead of the scoped alias. Stubs and disabled presets have no resolved
 * target, so they pass through to the provider's native stream behavior.
 */
function streamScopedModel(
  model: any,
  context: any,
  options: any,
): any {
  const alias = model.id as string;
  const killSwitch =
    process.env.PI_SCOPE_REWRITE === "0" || scopeProcess.rewriteDisabled;
  // The none scope resolves every request against the selected model; the
  // static target lookup below does not apply to it.
  if (state.preset === NONE_SCOPE && !killSwitch) {
    return streamFollowedModel(alias, context, options);
  }
  const target = state.targets[alias];
  // Snapshot at registration; a live find covers the stub stage, where
  // targets are known but no snapshot exists yet.
  const concrete =
    state.concreteModels[alias] ??
    (target && scopeRegistry ? scopeRegistry.find(target.provider, target.id) : undefined);
  if (killSwitch || !target || !concrete || !scopeRegistry) {
    debug(
      `streamSimple[${source}]: scoped/${alias} unresolved (kill=${killSwitch} target=${target ? `${target.provider}/${target.id}` : "none"} concrete=${concrete ? "yes" : "no"} registry=${scopeRegistry ? "yes" : "no"}), passing through to native behavior`,
    );
    return getApiProvider(model.api).streamSimple(
      model,
      context,
      withConversationSessionId(options),
    );
  }
  if (target.provider === "scoped") {
    throw new Error(
      `scoped/${alias} targets scoped/${target.id}: a scoped alias cannot resolve to another scoped alias`,
    );
  }
  const provider = scopeRegistry.getProvider(target.provider);
  if (!provider) {
    throw new Error(
      `scoped/${alias} cannot resolve: provider ${target.provider} is not registered`,
    );
  }
  debug(
    `streamSimple[${source}]: scoped/${alias} -> ${target.provider}/${target.id} (preset=${state.preset})`,
  );
  const { options: delegatedOptions, model: delegatedModel } = withTargetAuth(
    options,
    concrete,
    target,
  );
  return provider.streamSimple(delegatedModel, context, delegatedOptions);
}

/**
 * Resolve a scoped alias to the user's manually selected model and delegate
 * to that provider. Credentials are resolved per request because the
 * followed target changes with every manual selection.
 */
async function streamFollowedModel(
  alias: string,
  context: any,
  options: any,
): Promise<any> {
  const follow = scopeProcess.followModel;
  if (!follow) {
    throw new Error(
      `scoped/${alias}: scope none has no selected model yet; pick a model with the model picker and sub-agents and summaries will follow it`,
    );
  }
  if (!scopeRegistry) {
    throw new Error(
      `scoped/${alias}: scope none cannot resolve the selected model before session start`,
    );
  }
  const concrete = scopeRegistry.find(follow.provider, follow.id);
  if (!concrete) {
    throw new Error(
      `scoped/${alias}: selected model ${follow.provider}/${follow.id} is not available; pick another model with the model picker`,
    );
  }
  const auth = await scopeRegistry.getApiKeyAndHeaders(concrete);
  if (!auth.ok) {
    throw new Error(
      `scoped/${alias}: no credentials for selected model ${follow.provider}/${follow.id}: ${auth.error}`,
    );
  }
  const provider = scopeRegistry.getProvider(follow.provider);
  if (!provider) {
    throw new Error(
      `scoped/${alias}: provider ${follow.provider} is not registered`,
    );
  }
  debug(
    `streamSimple[${source}]: scoped/${alias} -> ${follow.provider}/${follow.id} (scope none)`,
  );
  const next: any = { ...withConversationSessionId(options) };
  if (auth.apiKey) next.apiKey = auth.apiKey;
  else delete next.apiKey;
  if (auth.headers) next.headers = auth.headers;
  if (auth.env) next.env = auth.env;
  return provider.streamSimple(
    auth.baseUrl ? { ...concrete, baseUrl: auth.baseUrl } : concrete,
    context,
    next,
  );
}

/**
 * Replace the scoped provider's credentials with the target provider's own
 * request auth: provider adapters take options.apiKey verbatim and never
 * resolve credentials, so forwarding the scoped options would send the main
 * provider's key to a different provider's endpoint. When no target auth is
 * resolved (pre-upgrade stubs), the scoped options pass through unchanged.
 */
function withTargetAuth(
  options: any,
  model: any,
  target: { provider: string; id: string } | undefined,
): { options: any; model: any } {
  const base = withConversationSessionId(options);
  const auth = target ? state.targetAuth[target.provider] : undefined;
  if (!auth) return { options: base, model };
  const next: any = { ...base };
  if (auth.apiKey) next.apiKey = auth.apiKey;
  else delete next.apiKey;
  if (auth.headers) next.headers = auth.headers;
  if (auth.env) next.env = auth.env;
  return {
    options: next,
    model: auth.baseUrl ? { ...model, baseUrl: auth.baseUrl } : model,
  };
}

/** Stub-shaped scoped provider config: present and dispatching to the hook, with no targets. */
function stubProviderConfig(name: string, modelNames: (id: string) => string): any {
  return {
    name,
    baseUrl: STUB_BASE_URL,
    api: "openai-completions",
    apiKey: "local",
    streamSimple: streamScopedModel,
    models: SCOPE_IDS.map((id) => ({ id, name: modelNames(id), ...STUB_MODEL })),
  };
}

/** Register the stub entries so `scoped/<id>` resolves at startup. */
function registerScopeStubs(pi: any): void {
  // Stubs have no resolved targets: pass-through until session_start
  // commits the target snapshot.
  pi.registerProvider(
    "scoped",
    stubProviderConfig(
      "Scoped",
      (id) => scopedModelName(id, `scoped/${id} (preset stub, upgraded at session start)`),
    ),
  );
  debug("factory: registered scoped stubs");
}

/** Prepare a provider replacement without changing committed scope state. */
async function prepareScopeRegistration(
  ctx: any,
  mapping: ScopeMapping,
): Promise<ScopeRegistration> {
  const concreteModels: Record<string, any> = {};
  const models: any[] = [];
  let mainAvailable = false;
  for (const id of SCOPE_IDS) {
    const entry = mapping.entries[id];
    const target = mapping.targets[id];
    if (!entry || !target) continue;
    const m = ctx.modelRegistry.find(target.provider, target.id);
    if (!m) {
      debug(
        `prepareScopeRegistration: target ${target.provider}/${target.id} not found in registry (skipping scoped/${id})`,
      );
      continue;
    }
    if (id === "main") mainAvailable = true;
    concreteModels[id] = m;
    debug(
      `prepareScopeRegistration: scoped/${id} <- ${m.provider}/${m.id} api=${m.api} baseUrl=${m.baseUrl}`,
    );

    // No per-model api: the alias inherits the provider-level api so the
    // composed provider dispatches every alias to the streamSimple hook,
    // regardless of the target's own api. The concrete snapshot (m) keeps
    // its real api for the delegated target provider.
    models.push({
      id,
      name: scopedModelName(id, m.name),
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
  // The internal summary target is validated alongside the work aliases so a
  // misconfigured preset fails registration clearly instead of silently
  // routing compaction or branch summaries at summary time. It is never added
  // to `models`, so scoped/summary stays out of normal model selection.
  const summaryEntry = mapping.entries[SUMMARY_ALIAS];
  const summaryTarget = mapping.targets[SUMMARY_ALIAS];
  let summaryAvailable = false;
  if (summaryEntry && summaryTarget) {
    const summaryModel = ctx.modelRegistry.find(
      summaryTarget.provider,
      summaryTarget.id,
    );
    if (summaryModel) {
      summaryAvailable = true;
      debug(
        `prepareScopeRegistration: scoped/${SUMMARY_ALIAS} <- ${summaryModel.provider}/${summaryModel.id} api=${summaryModel.api}`,
      );
    } else {
      debug(
        `prepareScopeRegistration: scoped/${SUMMARY_ALIAS} target ${summaryTarget.provider}/${summaryTarget.id} not found in registry`,
      );
    }
  } else {
    debug(
      `prepareScopeRegistration: preset has no scoped/${SUMMARY_ALIAS} entry`,
    );
  }

  if (models.length === 0) {
    debug("prepareScopeRegistration: no resolvable targets");
    return { count: 0, mainAvailable, summaryAvailable };
  }
  if (!mainAvailable) {
    debug("prepareScopeRegistration: scoped/main target is not resolvable");
    return { count: 0, mainAvailable, summaryAvailable };
  }
  const provider = mapping.targets.main;
  let apiKey: string | undefined;
  try {
    apiKey = await ctx.modelRegistry.getApiKeyForProvider(provider.provider);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return {
      count: 0,
      mainAvailable,
      summaryAvailable,
      failure: `could not resolve credentials for ${provider.provider}/${provider.id}: ${detail}`,
    };
  }
  if (!apiKey) {
    return {
      count: 0,
      mainAvailable,
      summaryAvailable,
      failure: `no credentials resolved for ${provider.provider}/${provider.id}`,
    };
  }

  // Resolve request auth per distinct target provider so delegated requests
  // carry the target's own credentials, not the main provider's key.
  const targetAuth: Record<string, TargetAuth> = {};
  const unresolved = new Set<string>();
  for (const providerId of new Set(Object.values(concreteModels).map((m) => m.provider))) {
    const representative = Object.values(concreteModels).find(
      (m) => m.provider === providerId,
    );
    if (!representative) continue;
    let auth: any;
    try {
      auth = await ctx.modelRegistry.getApiKeyAndHeaders(representative);
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      debug(
        `prepareScopeRegistration: credentials for ${providerId} failed: ${detail}`,
      );
      unresolved.add(`${providerId} (${detail})`);
      continue;
    }
    if (!auth.ok) {
      debug(
        `prepareScopeRegistration: credentials for ${providerId} unavailable: ${auth.error}`,
      );
      unresolved.add(`${providerId} (${auth.error})`);
      continue;
    }
    targetAuth[providerId] = {
      apiKey: auth.apiKey,
      headers: auth.headers,
      baseUrl: auth.baseUrl,
      env: auth.env,
    };
  }
  if (unresolved.size > 0) {
    return {
      count: 0,
      mainAvailable,
      summaryAvailable,
      failure: `could not resolve target credentials: ${[...unresolved].join(", ")}`,
    };
  }

  debug(
    `prepareScopeRegistration: preset="${mapping.preset}" models=[${models.map((x) => x.id).join(",")}] summary=${summaryAvailable} targetProvider=${provider.provider} apiKey=${apiKey.slice(0, 12)}... targets=${Object.keys(targetAuth).join(",")}`,
  );
  return {
    count: models.length,
    mainAvailable,
    summaryAvailable,
    concreteModels,
    targetAuth,
    providerConfig: {
      name: "Scoped",
      // The composed scoped provider only dispatches to the hook while the
      // model's api matches the provider-level api.
      api: "openai-completions",
      apiKey,
      streamSimple: streamScopedModel,
      models,
    },
  };
}

/**
 * Register the none scope: the aliases exist without static targets, and the
 * stream hook resolves each request to the selected model.
 */
function prepareNoneRegistration(): ScopeRegistration {
  debug(`prepareNoneRegistration: models=[${SCOPE_IDS.join(",")}] (follows the selected model)`);
  return {
    count: SCOPE_IDS.length,
    mainAvailable: true,
    summaryAvailable: true,
    concreteModels: {},
    targetAuth: {},
    providerConfig: stubProviderConfig(
      "Scoped (none)",
      (id) => scopedModelName(id, "Selected model (none scope)"),
    ),
  };
}

/** Atomically publish a prepared provider and its matching scope mapping. */
function commitScopeRegistration(
  pi: any,
  mapping: ScopeMapping,
  registration: ScopeRegistration,
): void {
  if (!registration.providerConfig)
    throw new Error("scope registration was not prepared for commit");
  pi.registerProvider("scoped", registration.providerConfig);
  state.preset = mapping.preset;
  state.entries = mapping.entries;
  state.targets = mapping.targets;
  state.concreteModels = registration.concreteModels ?? {};
  state.targetAuth = registration.targetAuth ?? {};
}

/** Snapshot the preset's dedicated summary target before asynchronous resolution begins. */
function snapshotSummaryTarget(ctx: any): ScopedSummaryTarget | undefined {
  const aliasModel = ctx.model;
  // The none scope has no static summary target: summaries follow the
  // selected model at the session's current thinking level. In none scope
  // the session model is usually concrete (entry unscopes it), so this check
  // runs before the scoped-session gate.
  if (state.preset === NONE_SCOPE) {
    const follow = scopeProcess.followModel;
    if (!follow) {
      throw new Error(
        `scope none has no selected model for ${SUMMARY_ALIAS}; pick a model with the model picker`,
      );
    }
    const followed = ctx.modelRegistry.find(follow.provider, follow.id);
    if (!followed) {
      throw new Error(
        `selected model ${follow.provider}/${follow.id} is unavailable for ${SUMMARY_ALIAS}`,
      );
    }
    return {
      alias: SUMMARY_ALIAS,
      entry: { model: `${follow.provider}/${follow.id}` },
      target: { provider: follow.provider, id: follow.id },
      model: { ...followed },
      thinkingLevel: ctx.thinkingLevel as SummaryThinkingLevel,
    };
  }

  // Direct non-scoped sessions keep Pi's native summary behavior.
  if (!aliasModel || aliasModel.provider !== "scoped") return undefined;

  // Scope-provider's compaction path is opt-in (PI_SCOPE_SUMMARY_COMPACTION);
  // when enabled, scoped sessions summarize through the preset's dedicated
  // target, independent of the active work alias. A missing or unavailable
  // target fails the summary rather than falling back to the work model.
  const alias = SUMMARY_ALIAS;
  const entry = state.entries[alias];
  const target = state.targets[alias];
  if (!entry || !target) {
    throw new Error(
      `preset "${state.preset}" has no scoped/${alias} target; check the scopeProvider settings`,
    );
  }

  const model = ctx.modelRegistry.find(target.provider, target.id);
  if (!model) {
    throw new Error(
      `concrete target ${target.provider}/${target.id} is unavailable`,
    );
  }

  return {
    alias,
    entry: { ...entry },
    target: { ...target },
    model: { ...model },
    thinkingLevel: (entry.thinking ??
      ctx.thinkingLevel) as SummaryThinkingLevel,
  };
}

async function resolveSummaryRequest(
  target: ScopedSummaryTarget,
  ctx: any,
): Promise<{
  model: any;
  apiKey?: string;
  headers?: Record<string, string>;
  env?: Record<string, string>;
  retry: { enabled: boolean; maxRetries: number; baseDelayMs: number };
}> {
  const retry = SettingsManager.create(
    ctx.cwd,
    getAgentDir(),
  ).getRetrySettings();
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(target.model);
  if (!auth.ok) {
    throw new Error(auth.error);
  }

  return {
    model: auth.baseUrl
      ? { ...target.model, baseUrl: auth.baseUrl }
      : target.model,
    apiKey: auth.apiKey,
    headers: auth.headers,
    env: auth.env,
    retry,
  };
}

function reportSummaryFailure(
  pi: any,
  operation: string,
  target: ScopedSummaryTarget | undefined,
  error: unknown,
): void {
  const concrete =
    state.preset === NONE_SCOPE
      ? "the followed model (scope none)"
      : target
        ? `${target.target.provider}/${target.target.id}`
        : "the configured scoped target";
  const detail = error instanceof Error ? error.message : String(error);
  try {
    publishScopeNote(
      pi,
      `scope: ERROR — ${operation} with ${concrete} failed: ${detail}. Check the target model and credentials, then retry.`,
      true,
    );
  } catch (reportError) {
    const reportDetail =
      reportError instanceof Error ? reportError.message : String(reportError);
    debug(
      `${operation}: could not report failure for ${concrete}: ${reportDetail}; original failure: ${detail}`,
    );
  }
}

/** Capture all mutable scope state before a provider replacement. */
function snapshotScope(ctx: any): ScopeSnapshot {
  const model = ctx.model;

  return {
    preset: state.preset,
    entries: { ...state.entries },
    targets: { ...state.targets },
    concreteModels: { ...state.concreteModels },
    targetAuth: { ...state.targetAuth },
    activePreset: scopeProcess.activePreset,
    upgradedPreset: scopeProcess.upgradedPreset,
    rewriteDisabled: scopeProcess.rewriteDisabled,
    providerConfig: ctx.modelRegistry.getRegisteredProviderConfig("scoped"),
    selectedModel:
      model &&
      typeof model.provider === "string" &&
      typeof model.id === "string"
        ? { provider: model.provider, id: model.id }
        : undefined,
    thinkingLevel:
      typeof ctx.thinkingLevel === "string" ? ctx.thinkingLevel : undefined,
  };
}

/**
 * Disable alias resolution when the provider registry cannot be restored
 * safely: with no targets, streamSimple delegates to the provider's native
 * stream behavior.
 */
function disableScopeRewrites(): void {
  state.entries = {};
  state.targets = {};
  state.concreteModels = {};
  state.targetAuth = {};
  scopeProcess.rewriteDisabled = true;
}

/** Restore the process and registry to a previously usable scope. */
function restoreScope(
  pi: any,
  ctx: any,
  snapshot: ScopeSnapshot,
): string | undefined {
  try {
    if (snapshot.providerConfig) {
      pi.registerProvider("scoped", snapshot.providerConfig);
    } else {
      ctx.modelRegistry.unregisterProvider("scoped");
    }

    const restoredMain = ctx.modelRegistry.find("scoped", "main");
    if (snapshot.providerConfig ? !restoredMain : restoredMain) {
      throw new Error(
        "the previous scoped provider did not restore its expected scoped/main entry",
      );
    }
    if (snapshot.selectedModel?.provider === "scoped") {
      const current = ctx.model;
      if (
        !current ||
        current.provider !== snapshot.selectedModel.provider ||
        current.id !== snapshot.selectedModel.id
      ) {
        throw new Error(
          `the previous selected model ${snapshot.selectedModel.provider}/${snapshot.selectedModel.id} could not be restored`,
        );
      }
    }
    if (snapshot.thinkingLevel !== undefined)
      pi.setThinkingLevel(snapshot.thinkingLevel);
  } catch (error) {
    disableScopeRewrites();
    const detail = error instanceof Error ? error.message : String(error);
    return `provider registry restoration failed: ${detail}; scoped alias resolution was disabled and the session must be restarted`;
  }

  state.preset = snapshot.preset;
  state.entries = snapshot.entries;
  state.targets = snapshot.targets;
  state.concreteModels = snapshot.concreteModels;
  state.targetAuth = snapshot.targetAuth;
  scopeProcess.activePreset = snapshot.activePreset;
  scopeProcess.upgradedPreset = snapshot.upgradedPreset;
  scopeProcess.rewriteDisabled = snapshot.rewriteDisabled;
  return undefined;
}

/**
 * Verify that provider re-registration refreshed the selected scoped/main
 * entry, then apply the preset's configured thinking level. Concrete models
 * are intentionally not changed.
 */
function refreshMainIfScopedMain(
  pi: any,
  ctx: any,
  label: string,
  report = true,
): boolean {
  const cur = ctx.model;
  if (!cur || cur.provider !== "scoped" || cur.id !== "main") {
    debug(
      `${label}: session model ${cur ? cur.provider + "/" + cur.id : "none"} is not scoped/main, left untouched`,
    );
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
    if (report) publishScopeNote(pi, msg, true);
    return false;
  }

  if (entry?.thinking) pi.setThinkingLevel(entry.thinking);
  debug(
    `${label}: refreshed scoped/main -> ${target ? `${target.provider}/${target.id}` : "<unset>"} thinking=${entry?.thinking ?? "unchanged"}`,
  );
  return true;
}

/** Publish the compact Powerline status for the active preset. */
function publishScopeStatus(ctx: any): void {
  ctx.ui.setStatus("scope", `scope:${state.preset}`);
}

/** Publish a one-line scope notice as a TUI-only session entry. */
function publishScopeNote(pi: any, text: string, error = false): void {
  pi.appendEntry("scoped", { text, error });
}

/** Store the selected preset without adding a visible transcript notice. */
function persistScopePreset(pi: any, preset: string): void {
  pi.appendEntry(SCOPE_STATE_ENTRY, { preset });
}

/** Whether the session is the top-level one; sub-agent sessions carry a parent session file. */
function isTopLevelSession(ctx: any): boolean {
  return !ctx?.sessionManager?.getHeader?.()?.parentSession;
}

/** Arm the leaving/entering prompt pair for the next agent turn after a switch. */
function armScopePromptTransition(previous: string, entering: string): void {
  pendingScopePrompt = {
    kind: "transition",
    leaving: activeEnablePreset ?? previous,
    entering,
  };
}

/** Arm a re-inject of the active preset's enable prompt for the next agent turn. */
function armScopePromptReinject(): void {
  pendingScopePrompt = { kind: "active" };
}

/**
 * Consume the armed prompt and return the text to inject, or undefined when the
 * armed transition has nothing to say. Records the preset whose enable text the
 * transcript now holds so a later switch to another preset emits its disable text.
 */
function takeScopePrompt(): string | undefined {
  const pending = pendingScopePrompt;
  pendingScopePrompt = undefined;
  if (!pending) return undefined;

  const active = pending.kind === "transition" ? pending.entering : state.preset;
  const parts: string[] = [];
  if (pending.kind === "transition" && pending.leaving !== pending.entering) {
    const disable = scopePromptText(pending.leaving, "disable");
    if (disable) parts.push(disable);
  }
  const enable = scopePromptText(active, "enable");
  if (enable) parts.push(enable);
  activeEnablePreset = enable ? active : undefined;

  return parts.length > 0 ? parts.join("\n\n") : undefined;
}

export default function scopeProvider(pi: any): void {
  // Scope notices are custom entries: they render in the transcript but never
  // enter LLM context, so the remap table is never sent to the model.
  pi.registerEntryRenderer("scoped", (entry: any, _options: any, theme: any) => {
    const data = entry.data as { text: string; error?: boolean };
    const styled = data.error
      ? theme.fg("error", data.text)
      : theme.fg("customMessageText", data.text);
    return new Text(styled);
  });
  pi.registerEntryRenderer(SCOPE_STATE_ENTRY, () => new Text(""));

  debug(
    `load: preset=${state.preset} activePreset=${scopeProcess.activePreset} rewrite=${process.env.PI_SCOPE_REWRITE !== "0"} log=${process.env.PI_SCOPE_LOG ?? "off"}`,
  );

  // Re-imports start with an empty table: (re)apply the live process preset so
  // the alias table matches what the process serves, and a re-imported
  // sub-agent session inherits the parent's current preset.
  if (scopeProcess.rewriteDisabled) {
    disableScopeRewrites();
  } else if (Object.keys(state.entries).length === 0) {
    applyPreset(scopeProcess.activePreset ?? state.preset);
  }

  // Every extension initialization registers stubs because replacement
  // runtimes need scoped/* entries before initial model resolution. A reused
  // registry, such as /reload, has no initial resolution between this
  // registration and its session_start upgrade; the process-wide upgraded
  // marker is not registration state.
  if (!scopeProcess.rewriteDisabled) {
    registerScopeStubs(pi);
  }

  pi.on("session_start", async (_event: any, ctx: any) => {
    scopeRegistry = ctx.modelRegistry;
    scopeSessionManager = ctx.sessionManager;
    if (scopeProcess.rewriteDisabled) return;

    const presets = readScopeConfig();
    const restoredPreset = findSavedScopePreset(
      ctx.sessionManager.getEntries(),
      presets,
    );
    const explicitLaunchPreset = process.env.PI_SCOPE;
    const persistLaunchPreset =
      !restoredPreset &&
      typeof explicitLaunchPreset === "string" &&
      (explicitLaunchPreset === NONE_SCOPE ||
        Boolean(presets[explicitLaunchPreset])) &&
      state.preset === explicitLaunchPreset;
    const restoreSource = restoredPreset ? "session-state" : "launch";
    if (restoredPreset) {
      applyPreset(restoredPreset);
      scopeProcess.activePreset = restoredPreset;
    }

    const registration =
      state.preset === NONE_SCOPE
        ? prepareNoneRegistration()
        : await prepareScopeRegistration(ctx, state);
    // Seed the followed model before mainTarget so the log line and the
    // notice below report the value this session will use.
    if (state.preset === NONE_SCOPE && isTopLevelSession(ctx)) {
      const seeded = latestConcreteModelChange(ctx.sessionManager.getEntries());
      if (seeded) scopeProcess.followModel = seeded;
    }
    const mainTarget =
      state.preset === NONE_SCOPE
        ? scopeProcess.followModel
        : registration.concreteModels?.main;
    debug(
      `session_start: restore source=${restoreSource} preset="${state.preset}" scoped/main -> ${mainTarget ? `${mainTarget.provider}/${mainTarget.id}` : "<unresolved>"}`,
    );

    if (
      registration.count === 0 ||
      !registration.mainAvailable ||
      !registration.summaryAvailable
    ) {
      const available = availablePresets().join(", ");
      const msg = registration.failure
        ? `scope: ERROR — preset "${state.preset}" ${registration.failure}; scoped provider registration was not changed. Check the provider credentials and restart the session.`
        : !registration.mainAvailable
          ? `scope: ERROR — preset "${state.preset}" has no resolvable scoped/main target; scoped/main requests will fail. Check the scopeProvider settings and models.`
          : !registration.summaryAvailable
            ? `scope: ERROR — preset "${state.preset}" has no resolvable scoped/${SUMMARY_ALIAS} target; compaction and /tree branch summaries would be cancelled. Check the scopeProvider settings and models.`
            : `scope: ERROR — preset "${state.preset}" has no resolvable targets in the model registry (available presets: ${available}); scoped/* model requests will fail. Check the scopeProvider settings and models.`;
      debug(`session_start: ${msg}`);
      publishScopeNote(pi, msg, true);

      return;
    }

    commitScopeRegistration(pi, state, registration);
    if (!refreshMainIfScopedMain(pi, ctx, "session_start")) return;
    if (isTopLevelSession(ctx)) armScopePromptReinject();
    if (state.preset === NONE_SCOPE) {
      const follow = scopeProcess.followModel;
      if (!follow) {
        publishScopeNote(
          pi,
          "scope none: no model selected yet; pick a model with the model picker and sub-agents and summaries will follow it",
        );
      } else if (!scopeRegistry.find(follow.provider, follow.id)) {
        publishScopeNote(
          pi,
          `scope: ERROR — selected model ${follow.provider}/${follow.id} is not available; pick another model with the model picker`,
          true,
        );
      }
    }
    if (persistLaunchPreset) persistScopePreset(pi, state.preset);
    // Record the usable preset for re-imported sessions after session_start
    // upgrades the current registry, including a registry reused by /reload.
    scopeProcess.upgradedPreset = state.preset;
    publishScopeStatus(ctx);
  });

  pi.on("session_compact", () => {
    armScopePromptReinject();
  });

  // Record the manually selected concrete model process-wide so every
  // session, including re-imported sub-agent sessions, resolves the none
  // scope against it. Only top-level sessions update it, and scoped
  // selections never do, so an alias can never resolve to itself.
  pi.on("model_select", (event: any, ctx: any) => {
    if (scopeProcess.rewriteDisabled) return;
    if (!isTopLevelSession(ctx)) return;
    const model = event?.model;
    if (
      !model ||
      typeof model.provider !== "string" ||
      typeof model.id !== "string" ||
      model.provider === "scoped"
    )
      return;
    scopeProcess.followModel = { provider: model.provider, id: model.id };
    debug(`model_select: scope none follows ${model.provider}/${model.id}`);
  });

  // The prompt is injected through the hook rather than sendMessage so it lands
  // ahead of the next user turn instead of as an eager LLM message.
  pi.on("before_agent_start", (_event: any, ctx: any) => {
    const content = takeScopePrompt();
    if (!content || !isTopLevelSession(ctx)) return undefined;
    return {
      message: { customType: SCOPE_PROMPT_ENTRY, content, display: true },
    };
  });

  pi.on("session_before_compact", async (event: any, ctx: any) => {
    // Off by default: warm sessions are summarized by the cached-compaction
    // extension through the session's own cached prompt, which a dedicated
    // summary call here would duplicate and then discard.
    if (process.env.PI_SCOPE_SUMMARY_COMPACTION !== "1") return;
    let target: ScopedSummaryTarget | undefined;
    try {
      target = snapshotSummaryTarget(ctx);
      if (!target) return;

      const request = await resolveSummaryRequest(target, ctx);
      const result = await compact(
        event.preparation,
        request.model,
        request.apiKey,
        request.headers,
        event.customInstructions,
        event.signal,
        target.thinkingLevel,
        undefined,
        request.env,
        request.retry,
      );
      if (event.signal.aborted) return { cancel: true };
      return { compaction: result };
    } catch (error) {
      reportSummaryFailure(pi, "compaction", target, error);
      return { cancel: true };
    }
  });

  pi.on("session_before_tree", async (event: any, ctx: any) => {
    if (
      !event.preparation.userWantsSummary ||
      event.preparation.entriesToSummarize.length === 0
    )
      return;

    let target: ScopedSummaryTarget | undefined;
    try {
      target = snapshotSummaryTarget(ctx);
      if (!target) return;

      const settings = SettingsManager.create(ctx.cwd, getAgentDir());
      const request = await resolveSummaryRequest(target, ctx);
      const result = await generateBranchSummary(
        event.preparation.entriesToSummarize,
        {
          model: request.model,
          apiKey: request.apiKey,
          headers: request.headers,
          env: request.env,
          signal: event.signal,
          customInstructions: event.preparation.customInstructions,
          replaceInstructions: event.preparation.replaceInstructions,
          reserveTokens: settings.getBranchSummarySettings().reserveTokens,
          retry: request.retry,
        },
      );
      if (event.signal.aborted || result.aborted) return { cancel: true };
      if (result.error) throw new Error(result.error);
      if (result.summary === undefined)
        throw new Error("the concrete target returned no branch summary");

      return {
        summary: {
          summary: result.summary,
          usage: result.usage,
          details: {
            readFiles: result.readFiles ?? [],
            modifiedFiles: result.modifiedFiles ?? [],
          },
        },
      };
    } catch (error) {
      reportSummaryFailure(pi, "branch summary", target, error);
      return { cancel: true };
    }
  });

  const switchScope = async (name: string, ctx: any): Promise<void> => {
    if (scopeProcess.rewriteDisabled) {
      publishScopeNote(
        pi,
        "scope: ERROR — scoped alias resolution is disabled because provider rollback failed. Restart the session before switching presets.",
        true,
      );

      return;
    }

    if (name === state.preset) {
      publishScopeNote(pi, `already on preset "${name}"`);

      return;
    }

    const previous = snapshotScope(ctx);
    const next = buildPreset(name);
    if (!next) {
      publishScopeNote(
        pi,
        `unknown preset "${name}" (available: ${availablePresets().join(", ")})`,
        true,
      );
      return;
    }

    try {
      const registration =
        name === NONE_SCOPE
          ? prepareNoneRegistration()
          : await prepareScopeRegistration(ctx, next);

      if (
        name !== NONE_SCOPE &&
        (registration.count === 0 ||
          !registration.mainAvailable ||
          !registration.summaryAvailable)
      ) {
        const available = availablePresets().join(", ");
        const msg = registration.failure
          ? `scope: ERROR — preset "${name}" ${registration.failure}; scoped provider registration was not changed. Check the provider credentials.`
          : !registration.mainAvailable
            ? `scope: ERROR — preset "${name}" has no resolvable scoped/main target; scoped/main requests will fail. Check the scopeProvider settings and models.`
            : !registration.summaryAvailable
              ? `scope: ERROR — preset "${name}" has no resolvable scoped/${SUMMARY_ALIAS} target; compaction and /tree branch summaries would be cancelled. Check the scopeProvider settings and models.`
              : `scope: ERROR — preset "${name}" has no resolvable targets in the model registry (available presets: ${available}); scoped/* model requests will fail. Check the scopeProvider settings and models.`;
        throw new Error(msg);
      }

      commitScopeRegistration(pi, next, registration);
      if (!refreshMainIfScopedMain(pi, ctx, `/scope ${name}`, false)) {
        throw new Error(
          `scope: ERROR — preset "${name}" could not refresh the selected scoped/main entry; scoped/main requests will fail. Check the scopeProvider settings and models.`,
        );
      }

      if (name === NONE_SCOPE)
        await establishFollowModel(pi, ctx, previous.concreteModels?.main);

      // Publish process-wide after the alias refresh succeeds so re-importing
      // sub-agent sessions only observes a usable preset.
      scopeProcess.activePreset = name;
      scopeProcess.upgradedPreset = state.preset;
      publishScopeStatus(ctx);
      persistScopePreset(pi, name);
      armScopePromptTransition(previous.preset, name);
    } catch (error) {
      const failure = error instanceof Error ? error.message : String(error);
      const rollbackFailure = restoreScope(pi, ctx, previous);
      const content = rollbackFailure
        ? `scope: ERROR — switching to preset "${name}" failed: ${failure}; rollback failed: ${rollbackFailure}. Check the scopeProvider settings and restart the session.`
        : `${failure}\nscope: previous preset "${previous.preset}" restored; alias resolution remains on its targets.`;
      debug(`/scope ${name}: ${content}`);
      publishScopeNote(pi, content, true);
      return;
    }

    publishScopeNote(pi, `scope preset: ${name}`);
  };

  const scopeSelectorItems = (): FuzzySelectorItem[] =>
    availablePresets().map((value) => ({ value, label: value }));

  const selectScope = async (
    ctx: any,
    initialSearchInput = "",
  ): Promise<void> => {
    const items = scopeSelectorItems();

    const selected = await selectFuzzyItem(ctx, "Select scope:", items, {
      initialSearchInput,
      initialSelectedValue: state.preset,
    });
    if (selected === undefined) return;

    await switchScope(selected, ctx);
  };

  pi.registerShortcut("ctrl+shift+z", {
    description: "Select scope",
    handler: selectScope,
  });

  pi.registerCommand("scope", {
    description:
      "Select a preset with /scope, or switch directly with /scope <preset>",
    getArgumentCompletions: (prefix: string) => {
      const matches = filterFuzzyItems(scopeSelectorItems(), prefix);
      if (matches.length === 0) return null;

      return matches.map(({ value, label, description }) => ({
        value,
        label: label ?? value,
        description,
      }));
    },
    handler: async (args: string, ctx: any) => {
      const name = args.trim();
      const items = scopeSelectorItems();

      if (items.some((item) => item.value === name)) {
        await switchScope(name, ctx);
        return;
      }

      if (!ctx.hasUI) {
        throw new Error(
          "/scope requires interactive UI when no exact preset is provided",
        );
      }

      await selectScope(ctx, name);
    },
  });
}

function scopedModelName(id: string, name: string): string {
  return id === "main" ? `${name} [S]` : name;
}

/** The scope names the selector offers: configured presets plus built-in none. */
function availablePresets(): string[] {
  return [
    ...Object.keys(readScopeConfig()).filter((name) => name !== NONE_SCOPE),
    NONE_SCOPE,
  ];
}


/** The newest non-scoped model selection persisted on a session. */
function latestConcreteModelChange(
  entries: readonly unknown[],
): { provider: string; id: string } | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index] as any;
    if (
      entry?.type === "model_change" &&
      typeof entry.provider === "string" &&
      typeof entry.modelId === "string" &&
      entry.provider !== "scoped"
    ) {
      return { provider: entry.provider, id: entry.modelId };
    }
  }
  return undefined;
}

/**
 * Enter the none scope from the session's current model: a session still on
 * scoped/main is unscoped to the concrete model its preset resolved it to,
 * and an already-concrete session keeps its model; both become the followed
 * model so the manual selection starts where the session stands.
 */
async function establishFollowModel(
  pi: any,
  ctx: any,
  previousMain: { provider: string; id: string } | undefined,
): Promise<void> {
  const current = ctx.model;
  if (
    current &&
    typeof current.provider === "string" &&
    current.provider !== "scoped" &&
    typeof current.id === "string"
  ) {
    scopeProcess.followModel = { provider: current.provider, id: current.id };
    debug(
      `entering none: following the session's selected model ${current.provider}/${current.id}`,
    );
    return;
  }
  if (current?.provider === "scoped" && current?.id === "main" && previousMain) {
    const concrete = ctx.modelRegistry.find(
      previousMain.provider,
      previousMain.id,
    );
    if (!concrete) {
      publishScopeNote(
        pi,
        `scope: ERROR — scope none could not unscope scoped/main: ${previousMain.provider}/${previousMain.id} is no longer available${followedModelNote()}`,
        true,
      );
      return;
    }
    let switched = false;
    try {
      switched = await pi.setModel(concrete);
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      debug(`entering none: setModel failed: ${detail}`);
    }
    if (switched) {
      scopeProcess.followModel = {
        provider: concrete.provider,
        id: concrete.id,
      };
      debug(
        `entering none: unscoped scoped/main -> ${concrete.provider}/${concrete.id}`,
      );
      return;
    }
    publishScopeNote(
      pi,
      `scope: ERROR — scope none could not switch the session to ${concrete.provider}/${concrete.id}${followedModelNote()}`,
      true,
    );
    return;
  }

  // The session is on another scoped alias (or no model): the followed model
  // stays as is and scoped requests fail with a clear pick-a-model error.
}

/** The entry-failure advice: keep following an available picked model, else ask for a pick. */
function followedModelNote(): string {
  const follow = scopeProcess.followModel;
  if (follow && scopeRegistry?.find(follow.provider, follow.id)) {
    return `; scoped requests keep following ${follow.provider}/${follow.id} until you pick a model`;
  }
  return "; pick a model with the model picker";
}
