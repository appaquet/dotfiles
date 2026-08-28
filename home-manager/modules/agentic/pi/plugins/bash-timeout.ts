/**
 * Bash timeout extension.
 *
 * Applies a default and an enforced ceiling to bash tool-call timeouts. On each
 * bash `tool_call` it reads the Home Manager-managed config from the Pi agent
 * directory and: injects the default when the timeout is omitted, preserves an
 * in-range value, and blocks invalid or above-ceiling values before execution.
 * A missing or invalid config falls back to the built-in 300/1200s limits, so
 * enforcement is never bypassed. No model-prompt guidance is added.
 *
 * Pi imports are type-only, so plain Node (which cannot resolve the nix-store
 * Pi package) can still load this file for unit tests; the two trivial Pi
 * runtime helpers are inlined instead of imported.
 */
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type {
  BashToolCallEvent,
  ExtensionAPI,
  ToolCallEvent,
} from "@earendil-works/pi-coding-agent";

/** Validated limits for bash call timeouts, in seconds. */
export type TimeoutConfig = {
  defaultTimeoutSeconds: number;
  maxTimeoutSeconds: number;
};

/** Policy outcome for a single bash tool call. */
export type TimeoutDecision =
  | { action: "mutate"; timeout: number }
  | { action: "preserve" }
  | { action: "block"; reason: string };

/** Used whenever the managed config is missing or invalid. */
export const FALLBACK_CONFIG: TimeoutConfig = {
  defaultTimeoutSeconds: 300,
  maxTimeoutSeconds: 1200,
};

/** Config file name resolved under the Pi agent directory. */
export const CONFIG_FILE_NAME = "bash-timeout.json";

/**
 * Parse and validate a raw JSON config string.
 *
 * Any failure (bad JSON, wrong shape, non-positive or fractional limits,
 * default above maximum) yields the complete fallback rather than a
 * partially applied config.
 */
export function parseTimeoutConfig(raw: string): TimeoutConfig {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return FALLBACK_CONFIG;
  }
  if (typeof parsed !== "object" || parsed === null) return FALLBACK_CONFIG;

  const obj = parsed as Record<string, unknown>;
  const d = obj.defaultTimeoutSeconds;
  const m = obj.maxTimeoutSeconds;
  if (!isPositiveInt(d) || !isPositiveInt(m) || d > m) return FALLBACK_CONFIG;
  return { defaultTimeoutSeconds: d, maxTimeoutSeconds: m };
}

/**
 * Read and resolve the config file at `<agentDir>/<CONFIG_FILE_NAME>`.
 * A missing or unreadable file yields the fallback.
 */
export function loadTimeoutConfig(agentDir: string): TimeoutConfig {
  try {
    const raw = fs.readFileSync(path.join(agentDir, CONFIG_FILE_NAME), "utf8");
    return parseTimeoutConfig(raw);
  } catch {
    return FALLBACK_CONFIG;
  }
}

/**
 * Decide how to handle a bash call's explicit timeout against `config`:
 *
 * - omitted -> mutate the call to the configured default;
 * - finite positive value at or below the ceiling -> preserve it;
 * - zero, negative, or non-finite -> block;
 * - value above the ceiling -> block with an actionable reason.
 */
export function resolveTimeoutPolicy(
  config: TimeoutConfig,
  timeout?: number,
): TimeoutDecision {
  if (timeout === undefined) {
    return { action: "mutate", timeout: config.defaultTimeoutSeconds };
  }
  if (typeof timeout !== "number" || !Number.isFinite(timeout) || timeout <= 0) {
    return {
      action: "block",
      reason: `Bash timeout ${String(
        timeout,
      )} is not a valid positive finite number of seconds. Use a value between 1 and ${config.maxTimeoutSeconds} seconds.`,
    };
  }
  if (timeout > config.maxTimeoutSeconds) {
    return {
      action: "block",
      reason: `Bash timeout ${timeout}s exceeds the ${config.maxTimeoutSeconds}s ceiling. Reduce to at most ${config.maxTimeoutSeconds} seconds.`,
    };
  }
  return { action: "preserve" };
}

function isPositiveInt(value: unknown): value is number {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    Number.isInteger(value) &&
    value > 0
  );
}

/**
 * Resolve the Pi agent directory. Mirrors Pi's getAgentDir() (env
 * PI_CODING_AGENT_DIR, default ~/.pi/agent); inlined because a runtime import
 * of the Pi package is not resolvable from this repo's Node tests.
 */
function agentDir(): string {
  const envDir = process.env.PI_CODING_AGENT_DIR;
  if (envDir) {
    return envDir.startsWith("~")
      ? path.join(os.homedir(), envDir.slice(1))
      : envDir;
  }
  return path.join(os.homedir(), ".pi", "agent");
}

/**
 * Narrow a tool_call event to bash. Mirrors Pi's isToolCallEventType
 * (event.toolName === "bash"); inlined to keep Pi imports type-only.
 */
function isBashToolCallEvent(event: ToolCallEvent): event is BashToolCallEvent {
  return event.toolName === "bash";
}

export default function bashTimeout(pi: ExtensionAPI): void {
  pi.on("tool_call", (event) => {
    if (!isBashToolCallEvent(event)) return;

    const config = loadTimeoutConfig(agentDir());
    const decision = resolveTimeoutPolicy(config, event.input.timeout);

    if (decision.action === "mutate") {
      event.input.timeout = decision.timeout;
      return;
    }
    if (decision.action === "block") {
      return { block: true, reason: decision.reason };
    }
  });
}
