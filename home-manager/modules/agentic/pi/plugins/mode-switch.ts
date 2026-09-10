/**
 * Mode switch and orchestrator guard extension.
 *
 * The footer always shows the current session mode. `ctrl+shift+m` and `/mode`
 * open a fuzzy selector, and `/mode <builder|orchestrator>` sets it
 * explicitly. At launch the `PI_MODE` env var (builder|orchestrator) selects
 * the initial mode of a session with no persisted mode entry (analog of
 * `PI_SCOPE` for scope presets); an explicit valid value is persisted so a
 * later resume environment cannot change the selection. On resume/fork the
 * persisted entry wins. On `/new` the outgoing instance hands the current
 * mode to the replacement instance through Pi's session lifecycle events and
 * persists it in the new session; the transfer wins over `PI_MODE`.
 *
 * The model is reminded of the active mode by an injected reminder message on
 * the next agent turn after every session start (startup, reload, resume,
 * fork, new), every successful compaction (manual, threshold, overflow), and
 * every actual mode switch. The full builder/orchestrator rules live in the
 * persistent context; the reminder only selects which rule set applies.
 * Orchestrator mode additionally repeats its reminder every N turns (N from
 * `mode-switch.json` in the agent dir, default 10).
 *
 * The mode is persisted per session in a `mode-switch` custom entry and
 * restored on `session_start` (default: builder).
 *
 * In orchestrator mode the main session is restricted to project docs:
 * `read`/`write`/`edit` on any non-`*.md` path are blocked with a reason that
 * teaches sub-agent delegation, and a reminder message is injected every
 * N turns.
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, normalize } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  filterFuzzyItems,
  selectFuzzyItem,
  type FuzzySelectorItem,
} from "../lib/fuzzy-selector.ts";

export type Mode = "builder" | "orchestrator";

export const MODES: readonly Mode[] = ["builder", "orchestrator"];

/**
 * Process-lifetime key of the `/new` handoff slot. The outgoing extension
 * instance is torn down before the replacement instance starts, so the mode
 * has to survive on a both-visible slot rather than module state.
 */
export const MODE_HANDOFF_KEY = Symbol("mode-switch-handoff");

type NewSessionHandoff = { mode: Mode; sourceSessionFile?: string };

const DEFAULT_REMINDER_INTERVAL = 10;
const REMINDER =
  "👑 Orchestrator mode: the main session may only read/write project docs (*.md) — delegate all code/file work to a sub-agent via the Agent tool.";
const BUILDER_REMINDER =
  "You are running in 🔨 builder mode. Follow the builder-mode rules in <sub-agents-workflows>.";
const GUARDED_TOOLS = new Set(["read", "write", "edit"]);

type ToolCallEvent = { toolName?: unknown; input?: unknown };

const MODE_LABELS: Record<Mode, string> = {
  builder: "🔨",
  orchestrator: "👑",
};

const MODE_COLORS: Record<Mode, "muted" | "accent"> = {
  builder: "muted",
  orchestrator: "accent",
};

/**
 * Restore the persisted mode from session entries: the latest custom
 * `mode-switch` entry with a valid mode wins; malformed entries are skipped.
 * Returns `undefined` when the session has no persisted mode.
 */
export function restoreMode(entries: unknown[]): Mode | undefined {
  let restored: Mode | undefined;
  for (const entry of entries) {
    if (
      typeof entry !== "object" ||
      entry === null ||
      (entry as Record<string, unknown>).type !== "custom" ||
      (entry as Record<string, unknown>).customType !== "mode-switch"
    )
      continue;
    const data = (entry as { data?: unknown }).data;
    const mode =
      typeof data === "object" && data !== null
        ? (data as { mode?: unknown }).mode
        : undefined;
    if (isMode(mode)) restored = mode;
  }
  return restored;
}

export type ResolvedMode = {
  mode: Mode;
  invalid: boolean;
};

/**
 * Decide the startup mode: a mode transferred across `/new` wins, then the
 * latest persisted mode-switch entry, then the trimmed PI_MODE env value when
 * valid, then builder. `invalid` flags an unusable env value.
 */
export function resolveMode(
  entries: unknown[],
  env: unknown,
  transferred?: Mode,
): ResolvedMode {
  if (transferred) return { mode: transferred, invalid: false };
  const persisted = restoreMode(entries);
  if (persisted) return { mode: persisted, invalid: false };

  const value = typeof env === "string" ? env.trim() : "";
  if (value === "") return { mode: "builder", invalid: false };
  if (isMode(value)) return { mode: value, invalid: false };
  return { mode: "builder", invalid: true };
}

export type ModeArg =
  | { kind: "set"; mode: Mode }
  | { kind: "select"; query: string };

/** Parse a `/mode` argument into an exact set or a selector search query. */
export function parseModeArg(arg: string): ModeArg {
  const name = arg.trim();
  if (isMode(name)) return { kind: "set", mode: name };
  return { kind: "select", query: name };
}

export function modeLabel(mode: Mode): string {
  return MODE_LABELS[mode];
}

/** Extracts a path only from the supported file tools and string inputs. */
export function extractFilePath(event: ToolCallEvent): string | undefined {
  if (!GUARDED_TOOLS.has(event.toolName as string)) return undefined;
  if (typeof event.input !== "object" || event.input === null) return undefined;
  const path = (event.input as { path?: unknown }).path;
  if (typeof path !== "string" || path.trim() === "") return undefined;
  return path;
}

/** Returns whether a tool call violates the orchestrator file policy. */
export function shouldBlock(mode: Mode, event: ToolCallEvent): boolean {
  if (mode !== "orchestrator") return false;
  const path = extractFilePath(event);
  if (path === undefined) return false;
  return !normalize(path.trim()).endsWith(".md");
}

/** Reads a positive integer reminder interval, falling back on malformed config. */
export function readReminderInterval(
  agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"),
): number {
  try {
    const parsed: unknown = JSON.parse(
      readFileSync(join(agentDir, "mode-switch.json"), "utf8"),
    );
    const interval =
      typeof parsed === "object" && parsed !== null
        ? (parsed as { reminderInterval?: unknown }).reminderInterval
        : undefined;
    return typeof interval === "number" && Number.isInteger(interval) && interval > 0
      ? interval
      : DEFAULT_REMINDER_INTERVAL;
  } catch {
    return DEFAULT_REMINDER_INTERVAL;
  }
}

function isMode(value: unknown): value is Mode {
  return value === "builder" || value === "orchestrator";
}

export default function modeSwitch(pi: ExtensionAPI): void {
  let mode: Mode = "builder";
  let turns = 0;
  let remindOnNextTurn = false;
  const reminderInterval = readReminderInterval();

  function publishLabel(ctx: ExtensionContext): void {
    ctx.ui.setStatus(
      "mode",
      ctx.ui.theme.fg(MODE_COLORS[mode], modeLabel(mode)),
    );
  }

  function reminderMessage(target: Mode) {
    return target === "orchestrator"
      ? {
          message: {
            customType: "orchestrator-guard-reminder",
            content: REMINDER,
            display: true,
          },
        }
      : {
          message: {
            customType: "mode-switch-reminder",
            content: BUILDER_REMINDER,
            display: true,
          },
        };
  }

  function setMode(ctx: ExtensionContext, target: Mode): void {
    if (target === mode) {
      ctx.ui.notify(`mode-switch: already on ${mode}`, "info");
      return;
    }

    mode = target;
    turns = 0;
    remindOnNextTurn = true;
    pi.appendEntry("mode-switch", { mode });
    pi.events.emit("mode-switch:changed", { mode });
    publishLabel(ctx);
    ctx.ui.notify(`mode-switch: ${mode}`, "info");
  }

  function restore(
    ctx: ExtensionContext,
    event: { reason?: unknown; previousSessionFile?: unknown } = {},
  ): void {
    // Consume the handoff slot unconditionally: it only applies to a `new`
    // start whose previous session file matches the one the outgoing
    // instance reported (both absent for in-memory sessions); any other
    // start drops a stale slot.
    const slot = (
      globalThis as Record<symbol, NewSessionHandoff | undefined>
    )[MODE_HANDOFF_KEY];
    (globalThis as Record<symbol, NewSessionHandoff | undefined>)[
      MODE_HANDOFF_KEY
    ] = undefined;
    const handoff =
      event.reason === "new" &&
      slot !== undefined &&
      slot.sourceSessionFile === event.previousSessionFile
        ? slot
        : undefined;

    const entries = ctx.sessionManager.getEntries();
    const env = process.env.PI_MODE;
    const resolved = resolveMode(entries, env, handoff?.mode);

    if (resolved.invalid) {
      ctx.ui.notify(
        `mode-switch: invalid PI_MODE "${env}" (available: ${MODES.join(
          ", ",
        )}); defaulting to builder`,
        "warning",
      );
    }

    // Persist only choices that came from outside this session's entries:
    // a `/new` transfer or an explicit PI_MODE selection.
    const explicitEnv = typeof env === "string" ? env.trim() : "";
    if (handoff || (restoreMode(entries) === undefined && isMode(explicitEnv)))
      pi.appendEntry("mode-switch", { mode: resolved.mode });

    mode = resolved.mode;
    // Every start loses in-memory counter state; the reminder re-teaches the
    // active mode from the (possibly new or summarized) context.
    turns = 0;
    remindOnNextTurn = true;
    publishLabel(ctx);
  }

  const modeSelectorItems: readonly FuzzySelectorItem[] = MODES.map(
    (value) => ({ value, label: value }),
  );

  async function selectMode(
    ctx: ExtensionContext,
    initialSearchInput = "",
  ): Promise<void> {
    const selected = await selectFuzzyItem(
      ctx,
      "Select mode:",
      modeSelectorItems,
      { initialSearchInput, initialSelectedValue: mode },
    );
    if (selected === undefined) return;

    setMode(ctx, selected as Mode);
  }

  pi.on("session_start", (event: any, ctx: any) =>
    restore(ctx, { reason: event?.reason, previousSessionFile: event?.previousSessionFile }),
  );

  pi.on("session_before_switch", (event: any, ctx: any) => {
    if (event?.reason !== "new") return;
    (globalThis as Record<symbol, NewSessionHandoff | undefined>)[
      MODE_HANDOFF_KEY
    ] = {
      mode,
      sourceSessionFile: ctx?.sessionManager?.getSessionFile?.() ?? undefined,
    };
  });

  pi.on("session_compact", () => {
    // Compaction keeps the closure mode and the persisted entry; it only
    // resets the interval and re-arms the reminder because the summarized
    // context no longer contains the mode instruction.
    turns = 0;
    remindOnNextTurn = true;
  });

  pi.on("tool_call", (event) => {
    try {
      if (shouldBlock(mode, event as ToolCallEvent))
        return { block: true, reason: REMINDER };
    } catch {
      // A policy-check failure must not accidentally block normal work.
    }
    return undefined;
  });

  pi.on("before_agent_start", () => {
    if (remindOnNextTurn) {
      remindOnNextTurn = false;
      return reminderMessage(mode);
    }
    if (mode !== "orchestrator") return undefined;
    turns += 1;
    if (turns % reminderInterval === 0) return reminderMessage("orchestrator");
    return undefined;
  });

  pi.registerShortcut("ctrl+shift+m", {
    description: "Select mode",
    handler: selectMode,
  });

  pi.registerCommand("mode", {
    description:
      "Select the session mode, or set it with /mode <builder|orchestrator>",
    getArgumentCompletions: (prefix) => {
      const matches = filterFuzzyItems(modeSelectorItems, prefix);
      if (matches.length === 0) return null;

      return matches.map(({ value, label, description }) => ({
        value,
        label: label ?? value,
        description,
      }));
    },
    handler: async (args, ctx) => {
      const parsed = parseModeArg(args);

      if (parsed.kind === "set") {
        setMode(ctx, parsed.mode);
        return;
      }

      if (!ctx.hasUI) {
        throw new Error(
          "/mode requires interactive UI when no exact mode is provided",
        );
      }

      await selectMode(ctx, parsed.query);
    },
  });
}
