/**
 * Mode switch and orchestrator guard extension.
 *
 * The footer always shows the current session mode; `ctrl+shift+m` or `/mode`
 * toggles it, and `/mode <builder|orchestrator>` sets it explicitly. At
 * launch the `PI_MODE` env var (builder|orchestrator) selects the initial mode
 * of a session with no persisted mode entry (analog of `PI_SCOPE` for scope
 * presets); on resume/fork the persisted entry wins. Every
 * actual mode switch submits the target mode's prompt template (`/builder`
 * or `/orchestrator`) as a user message (queued as a followUp while the
 * agent is streaming); session start and same-mode sets send nothing. The
 * mode is persisted per session in a `mode-switch` custom entry and restored
 * on `session_start` (default: builder).
 *
 * In orchestrator mode the main session is restricted to project docs:
 * `read`/`write`/`edit` on any non-`*.md` path are blocked with a reason that
 * teaches sub-agent delegation, and a reminder message is injected on entering
 * the mode and then every N turns (N from `mode-switch.json` in the agent dir,
 * default 10).
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, normalize } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

export type Mode = "builder" | "orchestrator";

export const MODES: readonly Mode[] = ["builder", "orchestrator"];

const DEFAULT_REMINDER_INTERVAL = 10;
const REMINDER =
  "👑 Orchestrator mode: the main session may only read/write project docs (*.md) — delegate all code/file work to a sub-agent via the Agent tool.";
const GUARDED_TOOLS = new Set(["read", "write", "edit"]);

type ToolCallEvent = { toolName?: unknown; input?: unknown };

export type SwitchDecision =
  | { action: "noop"; next: Mode }
  | { action: "submit"; next: Mode; template: Mode };

const MODE_LABELS: Record<Mode, string> = {
  builder: "🔨",
  orchestrator: "👑",
};

const MODE_COLORS: Record<Mode, "muted" | "accent"> = {
  builder: "muted",
  orchestrator: "accent",
};

/**
 * Decide what switching `current` -> `target` does: every actual mode change
 * submits the target mode's prompt template; staying on the same mode is a
 * no-op (the caller only notifies).
 */
export function decideSwitch(current: Mode, target: Mode): SwitchDecision {
  if (target === current) return { action: "noop", next: target };
  return { action: "submit", next: target, template: target };
}

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

export type StartupPlan = {
  mode: Mode;
  submit: boolean;
  invalid: boolean;
};

/**
 * Decide the startup mode: a persisted mode-switch entry wins, otherwise the
 * trimmed PI_MODE env value when valid, otherwise builder. `submit` is true
 * only when the env var selects orchestrator on a session with no persisted
 * mode — the caller then goes through the real switch path so the mode prompt
 * is submitted like a manual switch. `invalid` flags an unusable env value.
 */
export function startupPlan(entries: unknown[], env: unknown): StartupPlan {
  const persisted = restoreMode(entries);
  if (persisted) return { mode: persisted, submit: false, invalid: false };

  const value = typeof env === "string" ? env.trim() : "";
  if (value === "") return { mode: "builder", submit: false, invalid: false };
  if (isMode(value))
    return { mode: value, submit: value === "orchestrator", invalid: false };
  return { mode: "builder", submit: false, invalid: true };
}

export type ModeArg =
  | { kind: "toggle" }
  | { kind: "set"; mode: Mode }
  | { kind: "unknown"; arg: string };

/** Parse a `/mode` argument: empty toggles, a mode name sets it, anything else is unknown. */
export function parseModeArg(arg: string): ModeArg {
  const name = arg.trim();
  if (name === "") return { kind: "toggle" };
  if (isMode(name)) return { kind: "set", mode: name };
  return { kind: "unknown", arg: name };
}

/** Submission options for a mode template: followUp delivery only while streaming (never steer). */
export function submissionOptions(isIdle: boolean): {
  expandPromptTemplates: true;
  deliverAs?: "followUp";
} {
  return isIdle
    ? { expandPromptTemplates: true }
    : { expandPromptTemplates: true, deliverAs: "followUp" };
}

export function modeLabel(mode: Mode): string {
  return MODE_LABELS[mode];
}

/**
 * The named mode template is available when a prompt-source command with that
 * name is registered; hosts without rendered prompts lack it.
 */
export function hasPromptTemplate(
  commands: readonly { name: string; source: string }[],
  name: string,
): boolean {
  return commands.some(
    (command) => command.name === name && command.source === "prompt",
  );
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

  function reminderMessage() {
    return {
      message: {
        customType: "orchestrator-guard-reminder",
        content: REMINDER,
        display: true,
      },
    };
  }

  function restore(ctx: ExtensionContext): void {
    const env = process.env.PI_MODE;
    const plan = startupPlan(ctx.sessionManager.getEntries(), env);

    if (plan.invalid) {
      ctx.ui.notify(
        `mode-switch: invalid PI_MODE "${env}" (available: ${MODES.join(
          ", ",
        )}); defaulting to builder`,
        "warning",
      );
    }

    if (!plan.submit) {
      mode = plan.mode;
      // Compaction loses in-memory counter state; entries are the source of truth.
      turns = 0;
      remindOnNextTurn = false;
      publishLabel(ctx);
      return;
    }

    // PI_MODE=orchestrator on a fresh session goes through the real switch
    // path so the mode prompt is submitted like a manual switch.
    const before = mode;
    setMode(ctx, plan.mode);
    if (mode === before) {
      // setMode bailed (template missing) without publishing a label.
      publishLabel(ctx);
    }
  }

  function setMode(ctx: ExtensionContext, target: Mode): void {
    const decision = decideSwitch(mode, target);

    if (decision.action === "noop") {
      ctx.ui.notify(`mode-switch: already on ${mode}`, "info");
      return;
    }

    if (!hasPromptTemplate(pi.getCommands(), decision.template)) {
      ctx.ui.notify(
        `mode-switch: /${decision.template} template not found; staying on ${mode}`,
        "warning",
      );
      return;
    }

    pi.sendUserMessage(
      `/${decision.template}`,
      submissionOptions(ctx.isIdle()),
    );

    mode = decision.next;
    turns = 0;
    // Entering orchestrator reminds on the very next turn; later switches wait for the interval.
    remindOnNextTurn = mode === "orchestrator";
    pi.appendEntry("mode-switch", { mode });
    pi.events.emit("mode-switch:changed", { mode });
    publishLabel(ctx);
    ctx.ui.notify(`mode-switch: ${mode}`, "info");
  }

  function toggleMode(ctx: ExtensionContext): void {
    setMode(ctx, mode === "builder" ? "orchestrator" : "builder");
  }

  pi.on("session_start", (_event, ctx) => restore(ctx));
  pi.on("session_compact", (_event, ctx) => restore(ctx));

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
    if (mode !== "orchestrator") return undefined;
    if (remindOnNextTurn) {
      remindOnNextTurn = false;
      return reminderMessage();
    }
    turns += 1;
    if (turns % reminderInterval === 0) return reminderMessage();
    return undefined;
  });

  pi.registerShortcut("ctrl+shift+m", {
    description: "Toggle builder/orchestrator mode",
    handler: async (ctx) => {
      toggleMode(ctx);
    },
  });

  pi.registerCommand("mode", {
    description:
      "Toggle the session mode, or set it with /mode <builder|orchestrator>",
    handler: async (args, ctx) => {
      const parsed = parseModeArg(args);

      if (parsed.kind === "toggle") {
        toggleMode(ctx);
        return;
      }

      if (parsed.kind === "set") {
        setMode(ctx, parsed.mode);
        return;
      }

      ctx.ui.notify(
        `mode-switch: unknown mode "${parsed.arg}" (available: ${MODES.join(", ")})`,
        "warning",
      );
    },
  });
}
