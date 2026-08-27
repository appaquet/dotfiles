/**
 * Mode switch extension.
 *
 * The footer always shows the current session mode; `ctrl+shift+m` or `/mode`
 * toggles it, and `/mode <builder|orchestrator>` sets it explicitly. Every
 * actual mode switch submits the target mode's prompt template (`/builder`
 * or `/orchestrator`) as a user message (queued as a followUp while the
 * agent is streaming); session start and same-mode sets send nothing. The
 * mode is persisted per session in a `mode-switch` custom entry and restored
 * on `session_start` (default: builder).
 */
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

export type Mode = "builder" | "orchestrator";

export const MODES: readonly Mode[] = ["builder", "orchestrator"];

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
 * `mode-switch` entry with a valid mode wins; malformed entries are skipped
 * (default: builder).
 */
export function restoreMode(entries: unknown[]): Mode {
  let restored: Mode = "builder";
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

function isMode(value: unknown): value is Mode {
  return value === "builder" || value === "orchestrator";
}

export default function modeSwitch(pi: ExtensionAPI): void {
  let mode: Mode = "builder";

  function publishLabel(ctx: ExtensionContext): void {
    ctx.ui.setStatus(
      "mode",
      ctx.ui.theme.fg(MODE_COLORS[mode], modeLabel(mode)),
    );
  }

  async function setMode(ctx: ExtensionContext, target: Mode): Promise<void> {
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
    pi.appendEntry("mode-switch", { mode });
    publishLabel(ctx);
    ctx.ui.notify(`mode-switch: ${mode}`, "info");
  }

  async function toggleMode(ctx: ExtensionContext): Promise<void> {
    await setMode(ctx, mode === "builder" ? "orchestrator" : "builder");
  }

  pi.on("session_start", (_event, ctx) => {
    mode = restoreMode(ctx.sessionManager.getEntries());
    publishLabel(ctx);
  });

  pi.registerShortcut("ctrl+shift+m", {
    description: "Toggle builder/orchestrator mode",
    handler: async (ctx) => {
      await toggleMode(ctx);
    },
  });

  pi.registerCommand("mode", {
    description:
      "Toggle the session mode, or set it with /mode <builder|orchestrator>",
    handler: async (args, ctx) => {
      const parsed = parseModeArg(args);

      if (parsed.kind === "toggle") {
        await toggleMode(ctx);
        return;
      }

      if (parsed.kind === "set") {
        await setMode(ctx, parsed.mode);
        return;
      }

      ctx.ui.notify(
        `mode-switch: unknown mode "${parsed.arg}" (available: ${MODES.join(", ")})`,
        "warning",
      );
    },
  });
}
