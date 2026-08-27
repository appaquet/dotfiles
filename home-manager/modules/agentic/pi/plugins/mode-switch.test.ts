import { expect, test } from "bun:test";
import {
  MODES,
  decideSwitch,
  hasPromptTemplate,
  modeLabel,
  parseModeArg,
  restoreMode,
  submissionOptions,
  type Mode,
  type SwitchDecision,
} from "./mode-switch.ts";
import { default as modeSwitch } from "./mode-switch.ts";

// ---------------------------------------------------------------------------
// Pure decision logic
// ---------------------------------------------------------------------------

test("decideSwitch: full decision table with exact action, next mode and template", () => {
  const table: Record<Mode, Record<Mode, SwitchDecision>> = {
    builder: {
      builder: { action: "noop", next: "builder" },
      orchestrator: {
        action: "submit",
        next: "orchestrator",
        template: "orchestrator",
      },
    },
    orchestrator: {
      builder: { action: "submit", next: "builder", template: "builder" },
      orchestrator: { action: "noop", next: "orchestrator" },
    },
  };

  for (const current of MODES)
    for (const target of MODES)
      expect(decideSwitch(current, target)).toEqual(table[current][target]);
});

test("decideSwitch: every mode change submits the target template", () => {
  expect(decideSwitch("builder", "orchestrator")).toEqual({
    action: "submit",
    next: "orchestrator",
    template: "orchestrator",
  });
  expect(decideSwitch("orchestrator", "builder")).toEqual({
    action: "submit",
    next: "builder",
    template: "builder",
  });
  expect(decideSwitch("builder", "builder")).toEqual({
    action: "noop",
    next: "builder",
  });
  expect(decideSwitch("orchestrator", "orchestrator")).toEqual({
    action: "noop",
    next: "orchestrator",
  });
});

test("restoreMode: defaults to builder without mode-switch entries", () => {
  expect(restoreMode([])).toBe("builder");
  expect(
    restoreMode([
      { type: "message", message: { role: "user" } },
      { type: "custom", customType: "preset-state", data: { name: "plan" } },
      { type: "compaction", summary: "old" },
    ]),
  ).toBe("builder");
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
  ).toBe("builder");
  expect(
    restoreMode([
      { type: "custom", customType: "mode-switch", data: undefined },
    ]),
  ).toBe("builder");
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

  expect(restoreMode(malformed)).toBe("builder");
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

test("parseModeArg: empty and whitespace-only arguments toggle", () => {
  expect(parseModeArg("")).toEqual({ kind: "toggle" });
  expect(parseModeArg("   ")).toEqual({ kind: "toggle" });
});

test("parseModeArg: trims explicit mode names", () => {
  expect(parseModeArg("builder")).toEqual({ kind: "set", mode: "builder" });
  expect(parseModeArg("  orchestrator  ")).toEqual({
    kind: "set",
    mode: "orchestrator",
  });
});

test("parseModeArg: anything else is unknown with the trimmed argument", () => {
  expect(parseModeArg("wizard")).toEqual({ kind: "unknown", arg: "wizard" });
  expect(parseModeArg("  BUILDER  ")).toEqual({
    kind: "unknown",
    arg: "BUILDER",
  });
  expect(parseModeArg("builder extra")).toEqual({
    kind: "unknown",
    arg: "builder extra",
  });
});

test("modeLabel: exact footer labels", () => {
  expect(modeLabel("builder")).toBe("🏭");
  expect(modeLabel("orchestrator")).toBe("👑");
});

test("submissionOptions: queues as followUp only while streaming", () => {
  expect(submissionOptions(true)).toEqual({
    expandPromptTemplates: true,
  });
  expect(submissionOptions(false)).toEqual({
    expandPromptTemplates: true,
    deliverAs: "followUp",
  });
});

test("hasPromptTemplate: requires a prompt-source command with the given name", () => {
  expect(hasPromptTemplate([], "orchestrator")).toBe(false);
  expect(
    hasPromptTemplate([{ name: "orchestrator", source: "extension" }], "orchestrator"),
  ).toBe(false);
  expect(
    hasPromptTemplate([{ name: "orchestrator", source: "skill" }], "orchestrator"),
  ).toBe(false);
  expect(
    hasPromptTemplate([{ name: "orchestratorx", source: "prompt" }], "orchestrator"),
  ).toBe(false);
  expect(
    hasPromptTemplate(
      [
        { name: "mode", source: "extension" },
        { name: "orchestrator", source: "prompt" },
      ],
      "orchestrator",
    ),
  ).toBe(true);
  expect(hasPromptTemplate([{ name: "builder", source: "prompt" }], "builder")).toBe(
    true,
  );
  expect(hasPromptTemplate([{ name: "builder", source: "prompt" }], "orchestrator")).toBe(
    false,
  );
});

// ---------------------------------------------------------------------------
// Factory behavior against a fake ExtensionAPI
// ---------------------------------------------------------------------------

type FakeCommand = { name: string; source: string };
type StatusSet = { key: string; value: string };
type Notify = { message: string; type: string };
type UserMessage = { content: string; options?: Record<string, unknown> };
type EntryAppend = { customType: string; data?: unknown };

type HarnessCtx = {
  ui: {
    theme: { fg: (color: string, text: string) => string };
    setStatus: (key: string, value: string | undefined) => void;
    notify: (message: string, type?: "info" | "warning" | "error") => void;
  };
  isIdle: () => boolean;
  sessionManager: { getEntries: () => unknown[] };
};

type Harness = {
  idle: boolean;
  commands: FakeCommand[];
  entries: unknown[];
  ctx: HarnessCtx;
  statuses: StatusSet[];
  notifies: Notify[];
  sends: UserMessage[];
  appends: EntryAppend[];
  shortcuts: Array<{
    key: string;
    description: string;
    handler: (ctx: HarnessCtx) => Promise<void>;
  }>;
  command: (args: string) => Promise<void>;
  commandDescription: string;
  startSession: () => void;
  toggle: () => Promise<void>;
};

function createHarness(options: {
  entries?: unknown[];
  commands?: FakeCommand[];
  idle?: boolean;
} = {}): Harness {
  const harness: Harness = {
    idle: options.idle ?? true,
    commands:
      options.commands ??
      [
        { name: "builder", source: "prompt" },
        { name: "orchestrator", source: "prompt" },
      ],
    entries: options.entries ?? [],
    ctx: {
      ui: {
        theme: { fg: (color, text) => `[${color}]${text}` },
        setStatus: (key, value) => {
          if (value !== undefined) harness.statuses.push({ key, value });
        },
        notify: (message, type = "info") =>
          harness.notifies.push({ message, type }),
      },
      isIdle: () => harness.idle,
      sessionManager: { getEntries: () => harness.entries },
    },
    statuses: [],
    notifies: [],
    sends: [],
    appends: [],
    shortcuts: [],
    command: async () => {
      throw new Error("mode command was not registered");
    },
    commandDescription: "",
    startSession: () => {
      throw new Error("session_start handler was not registered");
    },
    toggle: async () => {
      throw new Error("shortcut handler was not registered");
    },
  };
  const ctx = harness.ctx;

  let sessionStart: ((event: unknown, ctx: unknown) => void) | undefined;
  const pi = {
    on: (event: string, handler: unknown) => {
      if (event !== "session_start")
        throw new Error(`unexpected event registration: ${event}`);
      sessionStart = handler as typeof sessionStart;
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
      },
    ) => {
      if (name !== "mode")
        throw new Error(`unexpected command registration: ${name}`);
      harness.commandDescription = options.description ?? "";
      harness.command = (args: string) => options.handler(args, ctx);
    },
    appendEntry: (customType: string, data?: unknown) =>
      harness.appends.push({ customType, data }),
    getCommands: () => harness.commands,
    sendUserMessage: (content: string, options?: Record<string, unknown>) =>
      harness.sends.push({ content, options }),
  };

  modeSwitch(pi as never);
  harness.toggle = () => harness.shortcuts[0].handler(ctx);
  harness.startSession = () => {
    if (!sessionStart)
      throw new Error("session_start handler was not registered");
    sessionStart({}, ctx);
  };
  return harness;
}

test("factory: registers only session_start, the shortcut and the /mode command", () => {
  const h = createHarness();

  expect(h.shortcuts).toHaveLength(1);
  expect(h.shortcuts[0].key).toBe("ctrl+shift+m");
  expect(h.shortcuts[0].description).toBe("Toggle builder/orchestrator mode");
  expect(typeof h.shortcuts[0].handler).toBe("function");
  expect(h.commandDescription).toBe(
    "Toggle the session mode, or set it with /mode <builder|orchestrator>",
  );
});

test("session_start: fresh session shows the builder label and injects nothing", () => {
  const h = createHarness();
  h.startSession();

  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🏭" }]);
  expect(h.notifies).toEqual([]);
  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
});

test("session_start: restores the persisted mode and its label", () => {
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
});

test("session_start: restore of a session with only malformed entries defaults to builder", () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "wizard" } },
    ],
  });
  h.startSession();

  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🏭" }]);
});

test("toggle builder -> orchestrator while idle: submits /orchestrator, persists, relabels, notifies", async () => {
  const h = createHarness({ idle: true });
  h.startSession();
  await h.toggle();

  expect(h.sends).toEqual([
    { content: "/orchestrator", options: { expandPromptTemplates: true } },
  ]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🏭" },
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
  ]);
});

test("toggle builder -> orchestrator while streaming: queues the message as a followUp", async () => {
  const h = createHarness({ idle: false });
  h.startSession();
  await h.toggle();

  expect(h.sends).toEqual([
    {
      content: "/orchestrator",
      options: { expandPromptTemplates: true, deliverAs: "followUp" },
    },
  ]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
});

test("toggle orchestrator -> builder: submits /builder, persists, relabels, notifies", async () => {
  const h = createHarness();
  h.startSession();
  await h.toggle();
  await h.toggle();

  expect(h.sends).toEqual([
    { content: "/orchestrator", options: { expandPromptTemplates: true } },
    { content: "/builder", options: { expandPromptTemplates: true } },
  ]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🏭" },
    { key: "mode", value: "[accent]👑" },
    { key: "mode", value: "[muted]🏭" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
    { message: "mode-switch: builder", type: "info" },
  ]);
});

test("toggle orchestrator -> builder while streaming: queues the message as a followUp", async () => {
  const h = createHarness({ idle: false });
  h.startSession();
  await h.toggle();
  await h.toggle();

  expect(h.sends).toEqual([
    {
      content: "/orchestrator",
      options: { expandPromptTemplates: true, deliverAs: "followUp" },
    },
    {
      content: "/builder",
      options: { expandPromptTemplates: true, deliverAs: "followUp" },
    },
  ]);
});

test("toggle to orchestrator without the template: warns and changes nothing", async () => {
  const h = createHarness({ commands: [] });
  h.startSession();
  await h.toggle();

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🏭" }]);
  expect(h.notifies).toEqual([
    {
      message: "mode-switch: /orchestrator template not found; staying on builder",
      type: "warning",
    },
  ]);
});

test("toggle to orchestrator with a non-prompt orchestrator command: warns and changes nothing", async () => {
  const h = createHarness({
    commands: [{ name: "orchestrator", source: "extension" }],
  });
  h.startSession();
  await h.toggle();

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🏭" }]);
  expect(h.notifies).toEqual([
    {
      message: "mode-switch: /orchestrator template not found; staying on builder",
      type: "warning",
    },
  ]);
});

test("toggle to builder without the template: warns and changes nothing", async () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
    ],
    commands: [{ name: "orchestrator", source: "prompt" }],
  });
  h.startSession();
  await h.toggle();

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(h.notifies).toEqual([
    {
      message: "mode-switch: /builder template not found; staying on orchestrator",
      type: "warning",
    },
  ]);
});

test("toggle to builder with a non-prompt builder command: warns and changes nothing", async () => {
  const h = createHarness({
    entries: [
      { type: "custom", customType: "mode-switch", data: { mode: "orchestrator" } },
    ],
    commands: [
      { name: "builder", source: "extension" },
      { name: "orchestrator", source: "prompt" },
    ],
  });
  h.startSession();
  await h.toggle();

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[accent]👑" }]);
  expect(h.notifies).toEqual([
    {
      message: "mode-switch: /builder template not found; staying on orchestrator",
      type: "warning",
    },
  ]);
});

test("/mode with no argument toggles like the shortcut", async () => {
  const h = createHarness();
  h.startSession();
  await h.command(" ");

  expect(h.sends).toEqual([
    { content: "/orchestrator", options: { expandPromptTemplates: true } },
  ]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🏭" },
    { key: "mode", value: "[accent]👑" },
  ]);
});

test("/mode orchestrator sets explicitly from builder", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("orchestrator");

  expect(h.sends).toEqual([
    { content: "/orchestrator", options: { expandPromptTemplates: true } },
  ]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🏭" },
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
  ]);
});

test("/mode orchestrator while orchestrator: notify only, no message or entry", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("orchestrator");
  await h.command("orchestrator");

  expect(h.sends).toEqual([
    { content: "/orchestrator", options: { expandPromptTemplates: true } },
  ]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🏭" },
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
    { message: "mode-switch: already on orchestrator", type: "info" },
  ]);
});

test("/mode builder while builder: notify only, no message or entry", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("builder");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🏭" }]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: already on builder", type: "info" },
  ]);
});

test("/mode builder from orchestrator: submits /builder", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("orchestrator");
  await h.command("builder");

  expect(h.sends).toEqual([
    { content: "/orchestrator", options: { expandPromptTemplates: true } },
    { content: "/builder", options: { expandPromptTemplates: true } },
  ]);
  expect(h.appends).toEqual([
    { customType: "mode-switch", data: { mode: "orchestrator" } },
    { customType: "mode-switch", data: { mode: "builder" } },
  ]);
  expect(h.statuses).toEqual([
    { key: "mode", value: "[muted]🏭" },
    { key: "mode", value: "[accent]👑" },
    { key: "mode", value: "[muted]🏭" },
  ]);
  expect(h.notifies).toEqual([
    { message: "mode-switch: orchestrator", type: "info" },
    { message: "mode-switch: builder", type: "info" },
  ]);
});

test("/mode with an unknown argument: warns available modes, changes nothing", async () => {
  const h = createHarness();
  h.startSession();
  await h.command("wizard");

  expect(h.sends).toEqual([]);
  expect(h.appends).toEqual([]);
  expect(h.statuses).toEqual([{ key: "mode", value: "[muted]🏭" }]);
  expect(h.notifies).toEqual([
    {
      message: 'mode-switch: unknown mode "wizard" (available: builder, orchestrator)',
      type: "warning",
    },
  ]);
});

test("persisted switches restore in a fresh session over the same entries", async () => {
  const first = createHarness();
  first.startSession();
  await first.toggle();

  const resumed = createHarness({
    entries: first.appends.map((a) => ({
      type: "custom",
      customType: a.customType,
      data: a.data,
    })),
  });
  resumed.startSession();

  expect(resumed.statuses).toEqual([
    { key: "mode", value: "[accent]👑" },
  ]);
  expect(resumed.sends).toEqual([]);
});
