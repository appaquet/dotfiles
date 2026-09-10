import { expect, mock, test } from "bun:test";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Mode } from "./mode-switch.ts";

mock.module("../lib/fuzzy-selector.ts", () => ({
  filterFuzzyItems: (
    items: Array<{ value: string; label?: string; description?: string }>,
    query: string,
  ) => {
    if (!query) return [...items];

    const normalized = query.toLowerCase();
    return items.filter((item) => {
      const text = [item.value, item.label ?? "", item.description ?? ""]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      let position = 0;

      for (const character of normalized) {
        position = text.indexOf(character, position);
        if (position < 0) return false;
        position += 1;
      }

      return true;
    });
  },
  selectFuzzyItem: async (
    ctx: HarnessCtx,
    title: string,
    items: Array<{ value: string }>,
    options: {
      initialSearchInput?: string;
      initialSelectedValue?: string;
    } = {},
  ) => {
    const selectorCalls = (ctx as any).__selectorCalls as Harness["selectorCalls"];
    selectorCalls.push({
      title,
      values: items.map((item) => item.value),
      initialSearchInput: options.initialSearchInput ?? "",
      initialSelectedValue: options.initialSelectedValue,
    });
    return ctx.ui.custom<string>(() => undefined);
  },
}));

const {
  MODES,
  MODE_HANDOFF_KEY: HANDOFF_SYMBOL,
  modeLabel,
  parseModeArg,
  readReminderInterval,
  restoreMode,
  resolveMode,
  shouldBlock,
  default: modeSwitch,
} = await import("./mode-switch.ts");

// ---------------------------------------------------------------------------
// Pure decision logic
// ---------------------------------------------------------------------------

test("restoreMode: returns undefined without mode-switch entries", () => {
  expect(restoreMode([])).toBeUndefined();
  expect(
    restoreMode([
      { type: "message", message: { role: "user" } },
      { type: "custom", customType: "preset-state", data: { name: "plan" } },
      { type: "compaction", summary: "old" },
    ]),
  ).toBeUndefined();
});

test("restoreMode: latest mode-switch entry wins regardless of interleaving", () => {
  const builder = {
    type: "custom",
    customType: "mode-switch",
    data: { mode: "builder" },
  };
  const orchestrator = {
    type: "custom",
    customType: "mode-switch",
    data: { mode: "orchestrator" },
  };

  expect(restoreMode([orchestrator])).toBe("orchestrator");
  expect(
    restoreMode([
      orchestrator,
      { type: "custom", customType: "plan-mode", data: { enabled: true } },
      builder,
    ]),
  ).toBe("builder");
  expect(restoreMode([builder, orchestrator])).toBe("orchestrator");
});

test("restoreMode: ignores non-custom entries and entries without usable data", () => {
  expect(
    restoreMode([
      {
        type: "message",
        customType: "mode-switch",
        data: { mode: "orchestrator" },
      },
    ]),
  ).toBeUndefined();
  expect(
    restoreMode([
      { type: "custom", customType: "mode-switch", data: undefined },
    ]),
  ).toBeUndefined();
  expect(
    restoreMode([
      {
        type: "custom",
        customType: "mode-switch",
        data: { mode: "orchestrator", stale: true },
      },
    ]),
  ).toBe("orchestrator");
});

test("restoreMode: tolerates malformed entries and keeps the latest valid one", () => {
  const malformed = [
    null,
    42,
    "text",
    { type: "custom" },
    { type: "custom", customType: "mode-switch" },
    { type: "custom", customType: "mode-switch", data: null },
    { type: "custom", customType: "mode-switch", data: {} },
    { type: "custom", customType: "mode-switch", data: { mode: "wizard" } },
    { type: "custom", customType: "mode-switch", data: { mode: 42 } },
    { type: "custom", customType: "mode-switch", data: { mode: null } },
  ];
  const valid = {
    type: "custom",
    customType: "mode-switch",
    data: { mode: "orchestrator" },
  };

  expect(restoreMode(malformed)).toBeUndefined();
  expect(
    restoreMode([
      ...malformed.slice(0, 5),
      valid,
      ...malformed.slice(5),
    ]),
  ).toBe("orchestrator");
  // A malformed latest entry does not shadow the earlier valid one.
  expect(
    restoreMode([
      valid,
      { type: "custom", customType: "mode-switch", data: { mode: "wizard" } },
    ]),
  ).toBe("orchestrator");
});

test("resolveMode: transferred mode beats any persisted entry and PI_MODE value", () => {
  const persisted = (mode: Mode) => ({
    type: "custom",
    customType: "mode-switch",
    data: { mode },
  });

  for (const env of [undefined, "", "builder", "orchestrator", "banana", 42]) {
    expect(resolveMode([persisted("builder")], env, "orchestrator")).toEqual({
      mode: "orchestrator",
      invalid: false,
    });
    expect(resolveMode([persisted("orchestrator")], env, "builder")).toEqual({
      mode: "builder",
      invalid: false,
    });
  }
});

test("resolveMode: persisted entry wins over any PI_MODE value", () => {
  const builder = {
    type: "custom",
    customType: "mode-switch",
    data: { mode: "builder" },
  };
  const orchestrator = {
    type: "custom",
    customType: "mode-switch",
    data: { mode: "orchestrator" },
  };

  for (const env of [undefined, "", "builder", "orchestrator", "banana", 42]) {
    expect(resolveMode([builder], env, undefined)).toEqual({
      mode: "builder",
      invalid: false,
    });
    expect(resolveMode([orchestrator], env, undefined)).toEqual({
      mode: "orchestrator",
      invalid: false,
    });
  }
});

test("resolveMode: without transferred or persisted state the PI_MODE value selects the mode", () => {
  expect(resolveMode([], undefined, undefined)).toEqual({
    mode: "builder",
    invalid: false,
  });
  expect(resolveMode([], "", undefined)).toEqual({
    mode: "builder",
    invalid: false,
  });
  expect(resolveMode([], "   ", undefined)).toEqual({
    mode: "builder",
    invalid: false,
  });
  expect(resolveMode([], 42, undefined)).toEqual({
    mode: "builder",
    invalid: false,
  });
  expect(resolveMode([], "builder", undefined)).toEqual({
    mode: "builder",
    invalid: false,
  });
  expect(resolveMode([], "  orchestrator  ", undefined)).toEqual({
    mode: "orchestrator",
    invalid: false,
  });
});

test("resolveMode: invalid PI_MODE without other state defaults to builder and flags invalid", () => {
  expect(resolveMode([], "wizard", undefined)).toEqual({
    mode: "builder",
    invalid: true,
  });
  expect(resolveMode([], " ORCHESTRATOR ", undefined)).toEqual({
    mode: "builder",
    invalid: true,
  });
});

// ---------------------------------------------------------------------------
// /mode argument parsing
// ---------------------------------------------------------------------------

test("parseModeArg: empty and whitespace-only arguments select with an empty query", () => {
  expect(parseModeArg("")).toEqual({ kind: "select", query: "" });
  expect(parseModeArg("   ")).toEqual({ kind: "select", query: "" });
});

test("parseModeArg: trims explicit mode names", () => {
  expect(parseModeArg("builder")).toEqual({ kind: "set", mode: "builder" });
  expect(parseModeArg("  orchestrator  ")).toEqual({
    kind: "set",
    mode: "orchestrator",
  });
});

test("parseModeArg: non-exact values select with the trimmed query", () => {
  expect(parseModeArg("wizard")).toEqual({ kind: "select", query: "wizard" });
  expect(parseModeArg("  BUILDER  ")).toEqual({
    kind: "select",
    query: "BUILDER",
  });
  expect(parseModeArg("builder extra")).toEqual({
    kind: "select",
    query: "builder extra",
  });
});

test("modeLabel: exact footer labels", () => {
  expect(modeLabel("builder")).toBe("🔨");
  expect(modeLabel("orchestrator")).toBe("👑");
});

// ---------------------------------------------------------------------------
// Factory behavior against a fake ExtensionAPI
// ---------------------------------------------------------------------------

const REMINDER_MESSAGE = {
  message: {
    customType: "orchestrator-guard-reminder",
    content:
      "👑 Orchestrator mode: the main session may only read/write project docs (*.md) — delegate all code/file work to a sub-agent via the Agent tool.",
    display: true,
  },
};

const BUILDER_REMINDER_MESSAGE = {
  message: {
    customType: "mode-switch-reminder",
    content:
      "You are running in 🔨 builder mode. Follow the builder-mode rules in <sub-agents-workflows>.",
    display: true,
  },
};

type StatusSet = { key: string; value: string };
type Notify = { message: string; type: string };
type UserMessage = { content: string; options?: Record<string, unknown> };
type EntryAppend = { customType: string; data?: unknown };
type ModeChange = { event: string; data: unknown };

type SessionStartReason = "startup" | "reload" | "new" | "resume" | "fork";

type HarnessCtx = {
  hasUI: boolean;
  ui: {
    theme: { fg: (color: string, text: string) => string };
    setStatus: (key: string, value: string | undefined) => void;
    notify: (message: string, type?: "info" | "warning" | "error") => void;
    custom: <T>(factory: (...args: any[]) => unknown) => Promise<T>;
  };
  isIdle: () => boolean;
  sessionManager: {
    getEntries: () => unknown[];
    getSessionFile: () => string | undefined;
  };
};

type Harness = {
  idle: boolean;
  sessionFile: string | undefined;
  entries: unknown[];
  ctx: HarnessCtx;
  statuses: StatusSet[];
  notifies: Notify[];
  sends: UserMessage[];
  appends: EntryAppend[];
  modeChanges: ModeChange[];
  shortcuts: Array<{
    key: string;
    description: string;
    handler: (ctx: HarnessCtx) => Promise<void>;
  }>;
  command: (args: string) => Promise<void>;
  completions: (prefix: string) => Array<{
    value: string;
    label: string;
    description?: string;
  }> | null;
  commandDescription: string;
  selectorCalls: Array<{
    title: string;
    values: string[];
    initialSearchInput: string;
    initialSelectedValue?: string;
  }>;
  selection?: Mode;
  startSession: (reason?: SessionStartReason, previousSessionFile?: string) => void;
  beforeSwitch: (reason: "new" | "resume") => void;
  compact: (reason?: "manual" | "threshold" | "overflow") => void;
  shortcut: (selection?: Mode) => Promise<void>;
  toolCall: (event: unknown) => unknown;
  agentStart: () => unknown;
};

function createHarness(options: {
  entries?: unknown[];
  idle?: boolean;
  sessionFile?: string;
  resetHandoff?: boolean;
  agentDir?: string;
} = {}): Harness {
  // The extension's /new handoff outlives a single factory instance; reset it
  // by default so each test starts from a clean handoff slot.
  if ((options.resetHandoff ?? true) && HANDOFF_SYMBOL !== undefined)
    (globalThis as Record<symbol, unknown>)[HANDOFF_SYMBOL] = undefined;
  const harness: Harness = {
    idle: options.idle ?? true,
    sessionFile: options.sessionFile,
    entries: options.entries ?? [],
    ctx: {
      hasUI: true,
      ui: {
        theme: { fg: (color, text) => `[${color}]${text}` },
        setStatus: (key, value) => {
          if (value !== undefined) harness.statuses.push({ key, value });
        },
        notify: (message, type = "info") =>
          harness.notifies.push({ message, type }),
        custom: async <T>() => harness.selection as T,
      },
      isIdle: () => harness.idle,
      sessionManager: {
        getEntries: () => harness.entries,
        getSessionFile: () => harness.sessionFile,
      },
    },
    statuses: [],
    notifies: [],
    sends: [],
    appends: [],
    modeChanges: [],
    shortcuts: [],
    command: async () => {
      throw new Error("mode command was not registered");
    },
    completions: () => {
      throw new Error("mode completions were not registered");
    },
    commandDescription: "",
    selectorCalls: [],
    startSession: () => {
      throw new Error("session_start handler was not registered");
    },
    compact: () => {
      throw new Error("session_compact handler was not registered");
    },
    shortcut: async () => {
      throw new Error("shortcut handler was not registered");
    },
    toolCall: () => {
      throw new Error("tool_call handler was not registered");
    },
    agentStart: () => {
      throw new Error("before_agent_start handler was not registered");
    },
  };
  const ctx = harness.ctx;
  (ctx as any).__selectorCalls = harness.selectorCalls;

  let sessionStart: ((event: unknown, ctx: unknown) => void) | undefined;
  let sessionBeforeSwitch: ((event: unknown, ctx: unknown) => unknown) | undefined;
  let sessionCompact: ((event: unknown, ctx: unknown) => void) | undefined;
  let toolCall: ((event: unknown, ctx: unknown) => unknown) | undefined;
  let beforeAgentStart: ((event: unknown, ctx: unknown) => unknown) | undefined;
  const pi = {
    on: (event: string, handler: (event: unknown, ctx: unknown) => unknown) => {
      switch (event) {
        case "session_start":
          sessionStart = handler;
          break;
        case "session_before_switch":
          sessionBeforeSwitch = handler;
          break;
        case "session_compact":
          sessionCompact = handler;
          break;
        case "tool_call":
          toolCall = handler;
          break;
        case "before_agent_start":
          beforeAgentStart = handler;
          break;
        default:
          throw new Error(`unexpected event registration: ${event}`);
      }
    },
    events: {
      emit: (event: string, data: unknown) =>
        harness.modeChanges.push({ event, data }),
    },
    registerShortcut: (
      key: string,
      options: {
        description?: string;
        handler: (ctx: unknown) => Promise<void>;
      },
    ) => {
      harness.shortcuts.push({
        key,
        description: options.description ?? "",
        handler: options.handler as Harness["shortcuts"][number]["handler"],
      });
    },
    registerCommand: (
      name: string,
      options: {
        description?: string;
        handler: (args: string, ctx: unknown) => Promise<void>;
        getArgumentCompletions: Harness["completions"];
      },
    ) => {
      if (name !== "mode")
        throw new Error(`unexpected command registration: ${name}`);
      harness.commandDescription = options.description ?? "";
      harness.command = (args: string) => options.handler(args, ctx);
      harness.completions = options.getArgumentCompletions;
    },
    appendEntry: (customType: string, data?: unknown) =>
      harness.appends.push({ customType, data }),
    sendUserMessage: (content: string, options?: Record<string, unknown>) =>
      harness.sends.push({ content, options }),
  };

  // Point the extension's config read at a scratch agent dir when given.
  const previousAgentDir = process.env.PI_CODING_AGENT_DIR;
  if (options.agentDir !== undefined)
    process.env.PI_CODING_AGENT_DIR = options.agentDir;
  modeSwitch(pi as never);
  if (previousAgentDir === undefined)
    delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
  harness.shortcut = async (selection) => {
    harness.selection = selection;
    await harness.shortcuts[0].handler(ctx);
  };
  harness.startSession = (reason = "startup", previousSessionFile) => {
    if (!sessionStart)
      throw new Error("session_start handler was not registered");
    const event: Record<string, unknown> = { type: "session_start", reason };
    if (previousSessionFile !== undefined)
      event.previousSessionFile = previousSessionFile;
    sessionStart(event, ctx);
  };
  harness.beforeSwitch = (reason) => {
    if (!sessionBeforeSwitch)
      throw new Error("session_before_switch handler was not registered");
    return sessionBeforeSwitch(
      { type: "session_before_switch", reason },
      ctx,
    );
  };
  harness.compact = (reason = "manual") => {
    if (!sessionCompact)
      throw new Error("session_compact handler was not registered");
    sessionCompact({ type: "session_compact", reason }, ctx);
  };
  harness.toolCall = (event: unknown) => {
    if (!toolCall) throw new Error("tool_call handler was not registered");
    return toolCall(event, ctx);
  };
  harness.agentStart = () => {
    if (!beforeAgentStart)
      throw new Error("before_agent_start handler was not registered");
    return beforeAgentStart({}, ctx);
  };
  return harness;
}

test("factory: registers only session events, the shortcut and the /mode command", () => {
  const h = createHarness();

  expect(h.shortcuts).toHaveLength(1);
  expect(h.shortcuts[0].key).toBe("ctrl+shift+m");
  expect(h.shortcuts[0].description).toBe("Select mode");
  expect(typeof h.shortcuts[0].handler).toBe("function");
  expect(h.commandDescription).toBe(
    "Select the session mode, or set it with /mode <builder|orchestrator>",
  );
});

test("/mode completions preserve mode order and fuzzy-match values", () => {
  const h = createHarness();

  expect(h.completions("")).toEqual([
    { value: "builder", label: "builder" },
    { value: "orchestrator", label: "orchestrator" },
  ]);
  expect(h.completions("RCH")).toEqual([
    { value: "orchestrator", label: "orchestrator" },
  ]);
  expect(h.completions("zzz")).toBeNull();
});

test("session_start: fresh startup shows the builder label and arms the builder reminder", () => {
  const h = createHarness();
  h.startSession();

  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.notifies).toEqual([]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
  expect(h.agentStart()).toBeUndefined();
});

test("session_start: restores the persisted mode, its label and its reminder", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "builder" } },
      {
        type: "custom",
        customType: "mode-switch",
        data: { mode: "orchestrator" },
      },
    ],
  });
  h.startSession();

  expect(h.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(h.notifies).toEqual([]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
  expect(h.agentStart()).toBeUndefined();
});

test("session_start: restore of a session with only malformed entries defaults to builder and arms its reminder", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "wizard" } },
    ],
  });
  h.startSession();

  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.appends).toEqual([]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

// ---------------------------------------------------------------------------
// PI_MODE startup env var
// ---------------------------------------------------------------------------

function withPiMode(value: string | undefined, fn: () => void): void {
  const previous = process.env.PI_MODE;
  if (value === undefined) delete process.env.PI_MODE;
  else process.env.PI_MODE = value;
  try {
    fn();
  } finally {
    if (previous === undefined) delete process.env.PI_MODE;
    else process.env.PI_MODE = previous;
  }
}

test("session_start: PI_MODE=orchestrator on a fresh session selects, persists and arms orchestrator", () => {
  const h = createHarness();
  withPiMode("orchestrator", () => h.startSession());

  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.sends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(h.modeChanges).toEqual([]);
  expect(h.notifies).toEqual([]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE); // armed on entry
  expect(h.agentStart()).toBeUndefined();
  expect(blocked(h.toolCall({ toolName: "read", input: { path: "src/app.ts" } }))).toBe(true);
});

test("session_start: PI_MODE=builder on a fresh session persists the choice and arms the builder reminder", () => {
  const h = createHarness();
  withPiMode("builder", () => h.startSession());

  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.notifies).toEqual([]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
  expect(h.agentStart()).toBeUndefined();
});

test("session_start: invalid PI_MODE on a fresh session warns, stays builder and arms its reminder", () => {
  const h = createHarness();
  withPiMode("banana", () => h.startSession());

  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.notifies).toEqual([
    {
      message:
        'mode-switch: invalid PI_MODE "banana" (available: builder, orchestrator); defaulting to builder',
      type: "warning",
    },
  ]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("session_start: persisted orchestrator entry wins over PI_MODE=builder", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
    ],
  });
  withPiMode("builder", () => h.startSession());

  expect(h.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
  expect(blocked(h.toolCall({ toolName: "read", input: { path: "src/app.ts" } }))).toBe(true);
});

test("session_start: persisted builder entry wins over PI_MODE=orchestrator", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "builder" } },
    ],
  });
  withPiMode("orchestrator", () => h.startSession());

  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
  expect(h.toolCall({ toolName: "read", input: { path: "src/app.ts" } })).toBeUndefined();
});

test("mode shortcut opens the current-mode picker and cancellation changes no state", async () => {
  const h = createHarness();
  h.startSession();

  await h.shortcut();

  expect(h.selectorCalls).toEqual([
    {
      title: "Select mode:",
      values: ["builder", "orchestrator"],
      initialSearchInput: "",
      initialSelectedValue: "builder",
    },
  ]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.modeChanges).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.notifies).toEqual([]);
});

test("mode shortcut highlights a restored orchestrator mode", async () => {
  const h = createHarness({
    entries: [
      {
        type: "custom",
        customType: "mode-switch",
        data: { mode: "orchestrator" },
      },
    ],
  });
  h.startSession();

  await h.shortcut();

  expect(h.selectorCalls).toEqual([
    {
      title: "Select mode:",
      values: ["builder", "orchestrator"],
      initialSearchInput: "",
      initialSelectedValue: "orchestrator",
    },
  ]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.modeChanges).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(h.notifies).toEqual([]);
});

test("mode shortcut selecting the current mode preserves no-op feedback", async () => {
  const h = createHarness();
  h.startSession();

  await h.shortcut("builder");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.modeChanges).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: already on builder", type: "info" },
  ]);
});

test("mode shortcut selects orchestrator: persists, relabels, notifies and arms the reminder", async () => {
  const h = createHarness({ idle: true });
  h.startSession();
  await h.shortcut("orchestrator");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🔨" },
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
  ]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
});

test("mode shortcut emits the selected mode", async () => {
  const h = createHarness();
  h.startSession();
  await h.shortcut("orchestrator");

  expect(h.modeChanges).toEqual([
    { event: "mode-switch:changed", data: { mode: "orchestrator" } },
  ]);
});

test("mode shortcut while streaming switches modes without submitting a prompt", async () => {
  const h = createHarness({ idle: false });
  h.startSession();
  await h.shortcut("orchestrator");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
});

test("mode shortcut selects builder from orchestrator", async () => {
  const h = createHarness();
  h.startSession();
  await h.shortcut("orchestrator");
  await h.shortcut("builder");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🔨" },
    { key: "mode", value: "[accent]👑" },
    { key: "mode", value: "[muted]🔨" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
    { message: "mode-switch: builder", type: "info" },
  ]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("/mode with no argument opens the selector without toggling", async () => {
  const h = createHarness();
  h.startSession();

  await h.command(" ");

  expect(h.selectorCalls).toEqual([
    {
      title: "Select mode:",
      values: ["builder", "orchestrator"],
      initialSearchInput: "",
      initialSelectedValue: "builder",
    },
  ]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
});

test("/mode partial input opens a prefilled selector and confirms through setMode", async () => {
  const h = createHarness();
  h.selection = "orchestrator";
  h.startSession();

  await h.command("  rch  ");

  expect(h.selectorCalls).toEqual([
    {
      title: "Select mode:",
      values: ["builder", "orchestrator"],
      initialSearchInput: "rch",
      initialSelectedValue: "builder",
    },
  ]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
});

test("/mode orchestrator sets explicitly from builder", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("orchestrator");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🔨" },
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
  ]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
});

test("/mode orchestrator while orchestrator: notify only, no message, entry or rearm", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("orchestrator");
  await h.command("orchestrator");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🔨" },
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
    { message: "mode-switch: already on orchestrator", type: "info" },
  ]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE); // the switch one-shot, not a rearm
  expect(h.agentStart()).toBeUndefined();
});

test("/mode builder while builder: notify only, no message, entry or rearm", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("builder");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: already on builder", type: "info" },
  ]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE); // the startup one-shot
  expect(h.agentStart()).toBeUndefined();
});

test("/mode builder from orchestrator: switches without submitting a prompt", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("orchestrator");
  await h.command("builder");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🔨" },
    { key: "mode", value: "[accent]👑" },
    { key: "mode", value: "[muted]🔨" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
    { message: "mode-switch: builder", type: "info" },
  ]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("/mode unmatched input opens a prefilled selector and cancellation is a no-op", async () => {
  const h = createHarness();
  h.startSession();

  await h.command("wizard");

  expect(h.selectorCalls).toEqual([
    {
      title: "Select mode:",
      values: ["builder", "orchestrator"],
      initialSearchInput: "wizard",
      initialSelectedValue: "builder",
    },
  ]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(h.notifies).toEqual([]);
});

test("non-UI /mode rejects selector input but accepts an exact mode", async () => {
  const h = createHarness();
  h.ctx.hasUI = false;
  h.startSession();

  await expect(h.command("")).rejects.toThrow(
    "/mode requires interactive UI when no exact mode is provided",
  );
  await expect(h.command("rch")).rejects.toThrow(
    "/mode requires interactive UI when no exact mode is provided",
  );
  expect(h.selectorCalls).toEqual([]);

  await h.command("orchestrator");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
});

test("persisted switches restore in a fresh session over the same entries", async () => {
  const first = createHarness();
  first.startSession();
  await first.shortcut("orchestrator");

  const resumed = createHarness({
    entries: first.appends.map((a) => ({
      type: "custom",
      customType: a.customType,
      data: a.data,
    })),
  });
  resumed.startSession("resume");

  expect(resumed.statuses).toEqual([
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(resumed.sends).toEqual([]);
  expect(resumed.agentStart()).toEqual(REMINDER_MESSAGE);
});

// ---------------------------------------------------------------------------
// Orchestrator guard
// ---------------------------------------------------------------------------

function blocked(result: unknown): boolean {
  return (
    typeof result === "object" &&
    result !== null &&
    (result as { block?: unknown }).block === true
  );
}

test("shouldBlock: gates non-md file tools only in orchestrator mode", () => {
  expect(
    shouldBlock("orchestrator", { toolName: "read", input: { path: "src/app.ts" } }),
  ).toBe(true);
  expect(
    shouldBlock("orchestrator", { toolName: "write", input: { path: "src/app.ts" } }),
  ).toBe(true);
  expect(
    shouldBlock("orchestrator", { toolName: "read", input: { path: "docs/x/notes.md" } }),
  ).toBe(false);
  expect(
    shouldBlock("builder", { toolName: "read", input: { path: "src/app.ts" } }),
  ).toBe(false);
  expect(
    shouldBlock("builder", { toolName: "write", input: { path: "src/app.ts" } }),
  ).toBe(false);
  expect(
    shouldBlock("orchestrator", { toolName: "bash", input: { command: "cat src/app.ts" } }),
  ).toBe(false);
});

test("shouldBlock: passes unknown tools and malformed paths", () => {
  expect(shouldBlock("orchestrator", { toolName: "grep", input: {} })).toBe(false);
  expect(shouldBlock("orchestrator", { toolName: "read" })).toBe(false);
  expect(shouldBlock("orchestrator", { toolName: "read", input: { path: 42 } })).toBe(false);
  expect(shouldBlock("orchestrator", { toolName: "read", input: { path: "" } })).toBe(false);
});

test("factory: session_start restores the orchestrator gate over persisted entries", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
    ],
  });
  h.startSession();

  const result = h.toolCall({ toolName: "read", input: { path: "src/app.ts" } });
  expect(blocked(result)).toBe(true);
  expect((result as { reason: string }).reason).toContain("Orchestrator mode");
  expect((result as { reason: string }).reason).toContain("sub-agent");
  expect(h.toolCall({ toolName: "write", input: { path: "docs/notes.md" } })).toBeUndefined();
});

test("factory: unknown tools and missing paths never block in orchestrator mode", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
    ],
  });
  h.startSession();

  expect(h.toolCall({ toolName: "bash", input: { command: "ls" } })).toBeUndefined();
  expect(h.toolCall({ toolName: "read" })).toBeUndefined();
  expect(h.toolCall({ toolName: "read", input: {} })).toBeUndefined();
});

test("factory: shortcut mode selection arms and disarms the gate", async () => {
  const h = createHarness();
  h.startSession();
  expect(h.toolCall({ toolName: "edit", input: { path: "x.ts" } })).toBeUndefined();
  await h.shortcut("orchestrator");
  expect(blocked(h.toolCall({ toolName: "edit", input: { path: "x.ts" } }))).toBe(true);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
  await h.shortcut("builder");
  expect(h.toolCall({ toolName: "edit", input: { path: "x.ts" } })).toBeUndefined();
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("factory: reminder fires on turn ten and never in builder mode", async () => {
  const h = createHarness();
  h.startSession();
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE); // startup one-shot
  await h.shortcut("orchestrator");
  // Entering orchestrator consumes its one-shot reminder before the interval counts.
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
  for (let i = 0; i < 9; i++) expect(h.agentStart()).toBeUndefined();
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
  expect(h.agentStart()).toBeUndefined();
  await h.shortcut("builder");
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("factory: reminder is immediate when switching into orchestrator", async () => {
  const h = createHarness();
  h.startSession();
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE); // startup one-shot
  await h.shortcut("orchestrator");

  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
  expect(h.agentStart()).toBeUndefined();
});

// ---------------------------------------------------------------------------
// Session reminders and /new lifecycle handoff
// ---------------------------------------------------------------------------

test("session_start: every start reason restores the mode and arms exactly one reminder", () => {
  for (const reason of ["startup", "reload", "resume", "fork"] as const) {
    const h = createHarness({
      entries: [
        { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
      ],
    });
    h.startSession(reason);

    expect(h.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
    expect(h.appends).toEqual([]);
    expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
    expect(h.agentStart()).toBeUndefined();
  }
});

test("session_start: fresh builder starts arm the builder one-shot reminder", () => {
  for (const reason of ["startup", "reload"] as const) {
    const h = createHarness();
    h.startSession(reason);

    expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
    expect(h.appends).toEqual([]);
    expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
    expect(h.agentStart()).toBeUndefined();
  }
});

test("builder: the one-shot reminder fires once and never periodically", () => {
  const h = createHarness();
  h.startSession();
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
  for (let i = 0; i < 30; i++) expect(h.agentStart()).toBeUndefined();
});

test("orchestrator: the periodic interval resumes after the one-shot reminder", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
    ],
  });
  h.startSession();
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE); // one-shot consumed
  for (let i = 0; i < 9; i++) expect(h.agentStart()).toBeUndefined();
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE); // default interval of 10
});

test("live switch: each change arms exactly one matching one-shot reminder", async () => {
  const h = createHarness();
  h.startSession();
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);

  await h.shortcut("orchestrator");
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.modeChanges).toEqual([
    { event: "mode-switch:changed", data: { mode: "orchestrator" } },
  ]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);

  await h.shortcut("builder");
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("live switch: selecting the current mode does not rearm the reminder", async () => {
  const h = createHarness();
  h.startSession();
  await h.shortcut("builder");

  expect(h.appends).toEqual([]);
  expect(h.modeChanges).toEqual([]);
  expect(h.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE); // still the startup one-shot
  expect(h.agentStart()).toBeUndefined();
});

test("session_compact: every reason preserves the mode and arms the one-shot reminder", () => {
  for (const reason of ["manual", "threshold", "overflow"] as const) {
    for (const mode of MODES) {
      const h = createHarness({
        entries: [
          { type: "custom", customType: "mode-switch", data: { mode } },
        ],
      });
      h.startSession();
      const expected =
        mode === "orchestrator" ? REMINDER_MESSAGE : BUILDER_REMINDER_MESSAGE;
      expect(h.agentStart()).toEqual(expected); // startup one-shot consumed

      h.compact(reason);

      expect(h.statuses).toEqual([
        {
          key: "mode",
          value: mode === "orchestrator" ? "[accent]👑" : "[muted]🔨",
        },
      ]);
      expect(h.appends).toEqual([]);
      expect(h.modeChanges).toEqual([]);
      expect(h.agentStart()).toEqual(expected);
      expect(h.agentStart()).toBeUndefined();
    }
  }
});

test("/new: the outgoing orchestrator mode transfers into the replacement session", async () => {
  const outgoing = createHarness({ sessionFile: "/tmp/old.jsonl" });
  outgoing.startSession("startup");
  await outgoing.shortcut("orchestrator");
  outgoing.beforeSwitch("new");

  const replacement = createHarness({
    sessionFile: "/tmp/new.jsonl",
    resetHandoff: false,
  });
  replacement.startSession("new", "/tmp/old.jsonl");

  expect(replacement.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(replacement.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(replacement.agentStart()).toEqual(REMINDER_MESSAGE);
});

test("/new: the outgoing builder mode transfers and persists into the replacement session", async () => {
  const outgoing = createHarness({ sessionFile: "/tmp/old.jsonl" });
  outgoing.startSession("startup");
  outgoing.beforeSwitch("new");

  const replacement = createHarness({
    sessionFile: "/tmp/new.jsonl",
    resetHandoff: false,
  });
  replacement.startSession("new", "/tmp/old.jsonl");

  expect(replacement.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(replacement.appends).toEqual([
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
  expect(replacement.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("/new: the transferred mode beats a conflicting PI_MODE", async () => {
  const outgoing = createHarness({ sessionFile: "/tmp/old.jsonl" });
  outgoing.startSession("startup");
  outgoing.beforeSwitch("new");

  const replacement = createHarness({
    sessionFile: "/tmp/new.jsonl",
    resetHandoff: false,
  });
  withPiMode("orchestrator", () =>
    replacement.startSession("new", "/tmp/old.jsonl"),
  );

  expect(replacement.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(replacement.appends).toEqual([
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
});

test("/new: in-memory sessions transfer without session files", async () => {
  const outgoing = createHarness();
  outgoing.startSession("startup");
  await outgoing.shortcut("orchestrator");
  outgoing.beforeSwitch("new");

  const replacement = createHarness({ resetHandoff: false });
  replacement.startSession("new");

  expect(replacement.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(replacement.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
});

test("/new: a later capture supersedes a stale handoff", async () => {
  const first = createHarness({
    sessionFile: "/tmp/first.jsonl",
    resetHandoff: false,
  });
  first.startSession("startup");
  first.beforeSwitch("new");

  const second = createHarness({
    sessionFile: "/tmp/second.jsonl",
    resetHandoff: false,
  });
  second.startSession("startup");
  await second.shortcut("orchestrator");
  second.beforeSwitch("new");

  const replacement = createHarness({
    sessionFile: "/tmp/new.jsonl",
    resetHandoff: false,
  });
  replacement.startSession("new", "/tmp/second.jsonl");

  expect(replacement.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
});

test("/new: a non-new start clears a stale handoff", async () => {
  const outgoing = createHarness({ sessionFile: "/tmp/old.jsonl" });
  outgoing.startSession("startup");
  await outgoing.shortcut("orchestrator");
  outgoing.beforeSwitch("new");

  const next = createHarness({ sessionFile: "/tmp/new.jsonl", resetHandoff: false });
  next.startSession("resume");

  expect(next.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(next.appends).toEqual([]);
});

test("/new: a mismatched previous session file discards the handoff", async () => {
  const outgoing = createHarness({ sessionFile: "/tmp/old.jsonl" });
  outgoing.startSession("startup");
  await outgoing.shortcut("orchestrator");
  outgoing.beforeSwitch("new");

  const replacement = createHarness({
    sessionFile: "/tmp/other.jsonl",
    resetHandoff: false,
  });
  replacement.startSession("new", "/tmp/other.jsonl");

  expect(replacement.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(replacement.appends).toEqual([]);
});

test("/new: a resume switch never captures a handoff", async () => {
  const outgoing = createHarness({ sessionFile: "/tmp/old.jsonl" });
  outgoing.startSession("startup");
  await outgoing.shortcut("orchestrator");
  outgoing.beforeSwitch("resume");

  const replacement = createHarness({
    sessionFile: "/tmp/new.jsonl",
    resetHandoff: false,
  });
  replacement.startSession("new");

  expect(replacement.statuses).toEqual([{ key: "mode", value: "[muted]🔨" }]);
  expect(replacement.appends).toEqual([]);
  expect(replacement.agentStart()).toEqual(BUILDER_REMINDER_MESSAGE);
});

test("factory: session_compact preserves the mode and arms the one-shot reminder", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
    ],
  });
  h.startSession();
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE); // startup one-shot consumed
  h.compact("manual");
  // Compaction appends no state; it only resets the interval and re-arms the reminder.
  expect(h.appends).toEqual([]);
  expect(h.modeChanges).toEqual([]);
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE);
  expect(h.agentStart()).toBeUndefined();
});

test("readReminderInterval: honors mode-switch.json and falls back on malformed config", async () => {
  const dir = await mkdtemp(join(tmpdir(), "mode-switch-config-"));
  await writeFile(join(dir, "mode-switch.json"), JSON.stringify({ reminderInterval: 2 }));
  expect(readReminderInterval(dir)).toBe(2);

  const h = createHarness({ agentDir: dir });
  h.startSession();
  await h.shortcut("orchestrator");
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE); // immediate on switch
  expect(h.agentStart()).toBeUndefined();
  expect(h.agentStart()).toEqual(REMINDER_MESSAGE); // custom interval of 2

  await writeFile(join(dir, "mode-switch.json"), "not json");
  expect(readReminderInterval(dir)).toBe(10);
});
