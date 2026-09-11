import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import settingsDrift, {
  agentDirPath,
  driftEntries,
  formatReport,
  formatSummary,
  IGNORED_PATHS,
  isIgnored,
  leafEntries,
  loadDrift,
  NIX_SETTINGS_ENV,
} from "./settings-drift.ts";

const NIX_SETTINGS = {
  defaultProvider: "scoped",
  defaultModel: "main",
  theme: "catppuccin-mocha",
  packages: ["nix-package"],
  powerline: {
    preset: "default",
    layout: { left: ["model"], right: ["path"] },
  },
};

const RUNTIME_WITH_DRIFT = {
  ...NIX_SETTINGS,
  doubleEscapeAction: "tree",
  enableInstallTelemetry: false,
  hideThinkingBlock: false,
  lastChangelogVersion: "0.85.1",
  showCacheMissNotices: true,
  tokenSpeed: { slidingWindow: 1000 },
};

const SUMMARY_WITH_DRIFT =
  "Settings drift — 5 settings not owned by nix: doubleEscapeAction, plus 4 more. Details: /settings-drift";

// Factory output: RUNTIME_WITH_DRIFT after the default ignore list.
const REPORT_WITH_DRIFT = [
  "settings.json differs from nix-owned settings (5 runtime-only)",
  "",
  "runtime-only (add to dotfiles.pi.settings to let nix own them):",
  '  doubleEscapeAction = "tree"',
  "  enableInstallTelemetry = false",
  "  hideThinkingBlock = false",
  "  showCacheMissNotices = true",
  "  tokenSpeed.slidingWindow = 1000",
].join("\n");

// Unfiltered: every runtime-only key of RUNTIME_WITH_DRIFT, including
// lastChangelogVersion, which the default ignore list suppresses.
const SUMMARY_UNFILTERED =
  "Settings drift — 6 settings not owned by nix: doubleEscapeAction, plus 5 more. Details: /settings-drift";

const REPORT_UNFILTERED = [
  "settings.json differs from nix-owned settings (6 runtime-only)",
  "",
  "runtime-only (add to dotfiles.pi.settings to let nix own them):",
  '  doubleEscapeAction = "tree"',
  "  enableInstallTelemetry = false",
  "  hideThinkingBlock = false",
  '  lastChangelogVersion = "0.85.1"',
  "  showCacheMissNotices = true",
  "  tokenSpeed.slidingWindow = 1000",
].join("\n");

let agentDir: string;
let previousAgentDir: string | undefined;
let previousNixSettingsFile: string | undefined;

beforeEach(async () => {
  agentDir = await mkdtemp(join(tmpdir(), "pi-settings-drift-"));
  previousAgentDir = process.env.PI_CODING_AGENT_DIR;
  previousNixSettingsFile = process.env[NIX_SETTINGS_ENV];
  process.env.PI_CODING_AGENT_DIR = agentDir;
  delete process.env[NIX_SETTINGS_ENV];
});

afterEach(async () => {
  restoreEnv("PI_CODING_AGENT_DIR", previousAgentDir);
  restoreEnv(NIX_SETTINGS_ENV, previousNixSettingsFile);
  await rm(agentDir, { recursive: true, force: true });
});

function restoreEnv(name: string, value: string | undefined): void {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}

async function writeAgentFile(name: string, contents: string): Promise<string> {
  const path = join(agentDir, name);
  await writeFile(path, contents);
  return path;
}

async function writeJsonFile(name: string, value: unknown): Promise<string> {
  return writeAgentFile(name, JSON.stringify(value));
}

/** Publish a Nix-owned snapshot the way the launch wrapper does. */
async function publishNixSettings(value: unknown): Promise<string> {
  const path = await writeJsonFile("pi-settings.json", value);
  process.env[NIX_SETTINGS_ENV] = path;
  return path;
}

// ---------------------------------------------------------------------------
// Leaf paths and drift
// ---------------------------------------------------------------------------

test("leafEntries: recurses objects and keeps arrays and scalars as leaves", () => {
  expect(
    leafEntries({
      theme: "catppuccin-mocha",
      packages: ["a", "b"],
      powerline: { preset: "default", layout: { left: ["model"] } },
      welcome: false,
    }),
  ).toEqual([
    { path: "theme", value: "catppuccin-mocha" },
    { path: "packages", value: ["a", "b"] },
    { path: "powerline.preset", value: "default" },
    { path: "powerline.layout.left", value: ["model"] },
    { path: "welcome", value: false },
  ]);
});

test("leafEntries: an empty object is itself a leaf", () => {
  expect(leafEntries({ empty: {} })).toEqual([{ path: "empty", value: {} }]);
});

test("driftEntries: reports runtime leaves that nix does not define", () => {
  expect(
    driftEntries(
      {
        owner: { configured: true, runtimeOnly: "keep", nested: { deep: 1 } },
        added: [1, 2],
      },
      { owner: { configured: true } },
    ),
  ).toEqual([
    { path: "owner.runtimeOnly", value: "keep" },
    { path: "owner.nested.deep", value: 1 },
    { path: "added", value: [1, 2] },
  ]);
});

test("driftEntries: a key defined by nix is not drift even when values differ", () => {
  expect(
    driftEntries(
      { theme: "dracula", packages: ["runtime-a", "runtime-b", "extra"] },
      { theme: "catppuccin-mocha", packages: ["nix-package"] },
    ),
  ).toEqual([]);
});

test("driftEntries: an empty runtime file has no drift", () => {
  expect(driftEntries({}, NIX_SETTINGS)).toEqual([]);
});

test("driftEntries: the full nix tree with one added key yields only that key", () => {
  expect(
    driftEntries({ ...NIX_SETTINGS, lastChangelogVersion: "0.85.1" }, NIX_SETTINGS),
  ).toEqual([{ path: "lastChangelogVersion", value: "0.85.1" }]);
});

// ---------------------------------------------------------------------------
// Ignore matching
// ---------------------------------------------------------------------------

test("isIgnored: matches an exact path", () => {
  expect(isIgnored("tokenSpeed", ["tokenSpeed"])).toBe(true);
});

test("isIgnored: an entry covers every descendant", () => {
  expect(isIgnored("tokenSpeed.slidingWindow", ["tokenSpeed"])).toBe(true);
  expect(isIgnored("powerline.layout.left", ["powerline"])).toBe(true);
});

test("isIgnored: a trailing wildcard matches exactly one segment", () => {
  expect(isIgnored("terminal.showImages", ["terminal.*"])).toBe(true);
  expect(isIgnored("terminal.images.autoResize", ["terminal.*"])).toBe(false);
  expect(isIgnored("terminal", ["terminal.*"])).toBe(false);
});

test("isIgnored: patterns are anchored to the full path", () => {
  expect(isIgnored("tokenSpeed", ["*Speed"])).toBe(false);
  expect(isIgnored("someTokenSpeed", ["tokenSpeed"])).toBe(false);
  expect(isIgnored("powerline.customItems", ["powerline.preset"])).toBe(false);
});

test("isIgnored: any matching entry wins over non-matching entries", () => {
  expect(isIgnored("terminal.images", ["powerline", "terminal.*"])).toBe(true);
});

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

test("formatSummary: matches the documented example", () => {
  expect(formatSummary(driftEntries(RUNTIME_WITH_DRIFT, NIX_SETTINGS))).toBe(
    SUMMARY_UNFILTERED,
  );
});

test("formatSummary: names the largest group and counts the rest", () => {
  const entries = [
    ...Array.from({ length: 7 }, (_, index) => ({
      path: `scopeProvider.preset${index}.model`,
      value: `model-${index}`,
    })),
    { path: "tokenSpeed.slidingWindow", value: 1000 },
    { path: "lastChangelogVersion", value: "0.85.1" },
  ];

  expect(formatSummary(entries)).toBe(
    "Settings drift — 9 settings not owned by nix: scopeProvider (7), plus 2 more. Details: /settings-drift",
  );
});

test("formatSummary: uses the singular for a single setting", () => {
  expect(formatSummary([{ path: "theme", value: "dracula" }])).toBe(
    "Settings drift — 1 setting not owned by nix: theme. Details: /settings-drift",
  );
});

test("formatSummary: counts the remaining settings", () => {
  const entries = Array.from({ length: 11 }, (_, index) => ({
    path: `key${index}`,
    value: index,
  }));

  expect(formatSummary(entries)).toBe(
    "Settings drift — 11 settings not owned by nix: key0, plus 10 more. Details: /settings-drift",
  );
});

test("formatReport: groups paths with their values in sorted order", () => {
  const entries = driftEntries(RUNTIME_WITH_DRIFT, NIX_SETTINGS);

  expect(formatReport(entries)).toBe(REPORT_UNFILTERED);
});

test("formatReport: reports an in-sync file", () => {
  expect(formatReport([])).toBe(
    "settings.json matches nix-owned settings (0 runtime-only)",
  );
});

// ---------------------------------------------------------------------------
// loadDrift
// ---------------------------------------------------------------------------

test("loadDrift: returns runtime-only paths and filters ignored ones", async () => {
  await publishNixSettings(NIX_SETTINGS);
  await writeJsonFile("settings.json", RUNTIME_WITH_DRIFT);

  expect(loadDrift(agentDir, ["tokenSpeed"])).toEqual([
    { path: "doubleEscapeAction", value: "tree" },
    { path: "enableInstallTelemetry", value: false },
    { path: "hideThinkingBlock", value: false },
    { path: "lastChangelogVersion", value: "0.85.1" },
    { path: "showCacheMissNotices", value: true },
  ]);

  // The default ignore list suppresses Pi-owned paths.
  expect(loadDrift(agentDir)).toEqual([
    { path: "doubleEscapeAction", value: "tree" },
    { path: "enableInstallTelemetry", value: false },
    { path: "hideThinkingBlock", value: false },
    { path: "showCacheMissNotices", value: true },
    { path: "tokenSpeed.slidingWindow", value: 1000 },
  ]);
});

test("loadDrift: reports runtime-only paths by default", async () => {
  await publishNixSettings({});
  await writeJsonFile("settings.json", { tokenSpeed: { slidingWindow: 1000 } });

  expect(IGNORED_PATHS).toEqual(["lastChangelogVersion"]);
  expect(loadDrift()).toEqual([
    { path: "tokenSpeed.slidingWindow", value: 1000 },
  ]);
});

test("loadDrift: resolves the agent directory from PI_CODING_AGENT_DIR", async () => {
  await publishNixSettings({ owner: { configured: true } });
  await writeJsonFile("settings.json", { owner: { configured: true, extra: 1 } });

  expect(agentDirPath()).toBe(agentDir);
  expect(loadDrift(agentDirPath())).toEqual([
    { path: "owner.extra", value: 1 },
  ]);
});

test("agentDirPath: treats an empty override as unset", () => {
  process.env.PI_CODING_AGENT_DIR = "";

  expect(agentDirPath()).toBe(join(homedir(), ".pi", "agent"));
});

test("loadDrift: returns undefined when the snapshot path is unset", async () => {
  await writeJsonFile("settings.json", RUNTIME_WITH_DRIFT);

  expect(loadDrift()).toBeUndefined();
});

test("loadDrift: returns undefined when the snapshot file is missing", async () => {
  process.env[NIX_SETTINGS_ENV] = join(agentDir, "absent.json");
  await writeJsonFile("settings.json", RUNTIME_WITH_DRIFT);

  expect(loadDrift()).toBeUndefined();
});

test("loadDrift: returns undefined when settings.json is malformed", async () => {
  await publishNixSettings(NIX_SETTINGS);
  await writeAgentFile("settings.json", "{ not json");

  expect(loadDrift()).toBeUndefined();
});

test("loadDrift: the summary caps only the paths that survive ignore filtering", async () => {
  await publishNixSettings({});
  const runtime = Object.fromEntries(
    Array.from({ length: 13 }, (_, index) => [`key${index}`, index]),
  );
  await writeJsonFile("settings.json", runtime);

  const entries = loadDrift(agentDir, ["key0", "key1", "key2"]);

  expect(entries?.map((entry) => entry.path)).toEqual([
    "key3",
    "key4",
    "key5",
    "key6",
    "key7",
    "key8",
    "key9",
    "key10",
    "key11",
    "key12",
  ]);
  expect(formatSummary(entries ?? [])).toBe(
    "Settings drift — 10 settings not owned by nix: key10, plus 9 more. Details: /settings-drift",
  );
});

// ---------------------------------------------------------------------------
// Extension factory
// ---------------------------------------------------------------------------

type Notify = { message: string; type: string };
test("wiring: the module exports the variable this extension reads and installs this file", async () => {
  const moduleSource = await readFile(
    new URL("../module.nix", import.meta.url),
    "utf8",
  );
  const pluginSource = await readFile(
    new URL("./default.nix", import.meta.url),
    "utf8",
  );

  expect(moduleSource).toContain(`environment.${NIX_SETTINGS_ENV}.value`);
  expect(pluginSource).toContain('".pi/agent/extensions/settings-drift.ts"');
});

function createHarness() {
  const notifies: Notify[] = [];
  const ctx = {
    mode: "tui",
    ui: {
      notify: (message: string, type = "info") => {
        notifies.push({ message, type });
      },
    },
  };

  let sessionStart: ((event: unknown, ctx: unknown) => void) | undefined;
  let command: ((args: string, ctx: unknown) => Promise<void>) | undefined;
  let commandDescription = "";

  const pi = {
    on: (event: string, handler: (event: unknown, ctx: unknown) => void) => {
      if (event !== "session_start")
        throw new Error(`unexpected event registration: ${event}`);
      sessionStart = handler;
    },
    registerCommand: (
      name: string,
      options: {
        description?: string;
        handler: (args: string, ctx: unknown) => Promise<void>;
      },
    ) => {
      if (name !== "settings-drift")
        throw new Error(`unexpected command registration: ${name}`);
      commandDescription = options.description ?? "";
      command = (args: string) => options.handler(args, ctx);
    },
  };

  settingsDrift(pi as never);

  return {
    notifies,
    commandDescription,
    startSession: (mode = "tui") => {
      if (!sessionStart)
        throw new Error("session_start handler was not registered");
      ctx.mode = mode;
      sessionStart({ type: "session_start", reason: "startup" }, ctx);
    },
    runCommand: (args = "") => {
      if (!command) throw new Error("settings-drift command was not registered");
      return command(args, ctx);
    },
  };
}

test("factory: registers the settings-drift command with a description", () => {
  const harness = createHarness();

  expect(harness.commandDescription).toBe(
    "List settings.json keys that nix does not own",
  );
});

test("factory: session_start notifies the summary of runtime-only drift", async () => {
  await publishNixSettings(NIX_SETTINGS);
  await writeJsonFile("settings.json", RUNTIME_WITH_DRIFT);
  const harness = createHarness();

  harness.startSession();

  expect(harness.notifies).toEqual([
    { message: SUMMARY_WITH_DRIFT, type: "warning" },
  ]);
});

test("factory: session_start stays silent when settings match nix", async () => {
  await publishNixSettings(NIX_SETTINGS);
  await writeJsonFile("settings.json", NIX_SETTINGS);
  const harness = createHarness();

  harness.startSession();

  expect(harness.notifies).toEqual([]);
});

test("factory: session_start stays silent outside tui mode", async () => {
  await publishNixSettings(NIX_SETTINGS);
  await writeJsonFile("settings.json", RUNTIME_WITH_DRIFT);
  const harness = createHarness();

  harness.startSession("rpc");

  expect(harness.notifies).toEqual([]);
});

test("factory: session_start stays silent when the snapshot path is unset", async () => {
  await writeJsonFile("settings.json", RUNTIME_WITH_DRIFT);
  const harness = createHarness();

  harness.startSession();

  expect(harness.notifies).toEqual([]);
});

test("factory: settings-drift command notifies the grouped report", async () => {
  await publishNixSettings(NIX_SETTINGS);
  await writeJsonFile("settings.json", RUNTIME_WITH_DRIFT);
  const harness = createHarness();

  await harness.runCommand("");

  expect(harness.notifies).toEqual([
    { message: REPORT_WITH_DRIFT, type: "info" },
  ]);
});

test("factory: settings-drift command reports an in-sync file", async () => {
  await publishNixSettings(NIX_SETTINGS);
  await writeJsonFile("settings.json", NIX_SETTINGS);
  const harness = createHarness();

  await harness.runCommand("");

  expect(harness.notifies).toEqual([
    {
      message: "settings.json matches nix-owned settings (0 runtime-only)",
      type: "info",
    },
  ]);
});

test("factory: settings-drift command warns when inputs are unreadable", async () => {
  const harness = createHarness();

  await harness.runCommand("");

  expect(harness.notifies).toEqual([
    {
      message: `settings-drift: cannot read ${NIX_SETTINGS_ENV} or settings.json`,
      type: "warning",
    },
  ]);
});
