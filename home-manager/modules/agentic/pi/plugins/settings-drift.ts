/**
 * Reports settings that the runtime `settings.json` holds but the Nix-owned
 * settings snapshot does not define, so keys written by Pi or its extensions
 * can be copied back into `dotfiles.pi.settings`.
 *
 * The snapshot path arrives through `PI_NIX_SETTINGS_FILE`, which the launch
 * wrapper exports while merging that same file into the runtime settings, so
 * drift means "the runtime file holds a path Nix does not own".
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** JSON value shape of Pi settings files. */
export type JsonValue =
  | null
  | boolean
  | number
  | string
  | JsonValue[]
  | { [key: string]: JsonValue };

/** A leaf of the settings tree: a dotted path and the value found there. */
export type DriftEntry = { path: string; value: JsonValue };

/** Environment variable carrying the Nix-owned settings snapshot path. */
export const NIX_SETTINGS_ENV = "PI_NIX_SETTINGS_FILE";

/** Paths reported at runtime but deliberately left to Pi and its extensions. */
export const IGNORED_PATHS: readonly string[] = [
  "lastChangelogVersion", // Pi owns this; a new value is written on every release
];

const SETTINGS_FILE = "settings.json";

/** Pi's agent directory, resolved exactly like Pi's getAgentDir(). */
export function agentDirPath(): string {
  const envDir = process.env.PI_CODING_AGENT_DIR;
  if (envDir) {
    return envDir.startsWith("~")
      ? join(homedir(), envDir.slice(1))
      : envDir;
  }

  return join(homedir(), ".pi", "agent");
}

/**
 * Flatten a settings tree into dotted leaf paths. Objects recurse; arrays and
 * scalars are leaves so an array is compared as one value rather than by index.
 */
export function leafEntries(value: JsonValue, prefix = ""): DriftEntry[] {
  if (!isJsonObject(value) || Object.keys(value).length === 0)
    return [{ path: prefix, value }];

  return Object.entries(value).flatMap(([key, child]) =>
    leafEntries(child, prefix === "" ? key : `${prefix}.${key}`),
  );
}

/** Leaf paths the runtime settings hold that the Nix-owned tree does not define. */
export function driftEntries(runtime: JsonValue, nix: JsonValue): DriftEntry[] {
  const owned = new Set(leafEntries(nix).map((entry) => entry.path));
  return leafEntries(runtime).filter(
    (entry) => entry.path !== "" && !owned.has(entry.path),
  );
}

/**
 * Whether a path is ignored. A literal entry covers itself and its
 * descendants; an entry containing `*` must match the whole path, with `*`
 * standing for exactly one segment.
 */
export function isIgnored(path: string, ignored: readonly string[]): boolean {
  const segments = path.split(".");

  return ignored.some((entry) => {
    const pattern = entry.split(".");
    const lengthMatches = pattern.includes("*")
      ? pattern.length === segments.length
      : pattern.length <= segments.length;
    if (!lengthMatches) return false;

    return pattern.every(
      (segment, index) => segment === "*" || segment === segments[index],
    );
  });
}

/**
 * One-line session-start summary: the top-level key with the most drift plus a
 * count of the rest, so the notice stays short and `/settings-drift` carries
 * the detail.
 */
export function formatSummary(entries: readonly DriftEntry[]): string {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    const group = entry.path.split(".")[0];
    counts.set(group, (counts.get(group) ?? 0) + 1);
  }

  const [topGroup, topCount] = [...counts.entries()].sort(
    ([leftGroup, leftCount], [rightGroup, rightCount]) =>
      rightCount - leftCount || (leftGroup < rightGroup ? -1 : 1),
  )[0];

  const label = topCount > 1 ? `${topGroup} (${topCount})` : topGroup;
  const rest = entries.length - topCount;
  const more = rest > 0 ? `, plus ${rest} more` : "";
  const noun = entries.length === 1 ? "setting" : "settings";

  return `Settings drift — ${entries.length} ${noun} not owned by nix: ${label}${more}. Details: /settings-drift`;
}

/** Grouped report listing every runtime-only path with its value. */
export function formatReport(entries: readonly DriftEntry[]): string {
  if (entries.length === 0)
    return "settings.json matches nix-owned settings (0 runtime-only)";

  const lines = [...entries]
    .sort((left, right) =>
      left.path < right.path ? -1 : left.path > right.path ? 1 : 0,
    )
    .map((entry) => `  ${entry.path} = ${JSON.stringify(entry.value)}`);

  return [
    `settings.json differs from nix-owned settings (${entries.length} runtime-only)`,
    "",
    "runtime-only (add to dotfiles.pi.settings to let nix own them):",
    ...lines,
  ].join("\n");
}

/**
 * Runtime-only paths of the current settings file, without the ignored ones.
 * Returns undefined when the snapshot path is unset or any input is unreadable,
 * which callers treat as "nothing to report" rather than as an error.
 */
export function loadDrift(
  agentDir = agentDirPath(),
  ignored: readonly string[] = IGNORED_PATHS,
): DriftEntry[] | undefined {
  const nixSettingsPath = process.env[NIX_SETTINGS_ENV];
  if (!nixSettingsPath) return undefined;

  const nixSettings = readJsonFile(nixSettingsPath);
  const runtimeSettings = readJsonFile(join(agentDir, SETTINGS_FILE));
  if (nixSettings === undefined || runtimeSettings === undefined)
    return undefined;

  return driftEntries(runtimeSettings, nixSettings).filter(
    (entry) => !isIgnored(entry.path, ignored),
  );
}

export default function settingsDrift(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    const entries = loadDrift();
    if (entries === undefined || entries.length === 0) return;

    // "warning" is what renders as a colored, one-line notice; "info" is dim.
    ctx.ui.notify(formatSummary(entries), "warning");
  });

  pi.registerCommand("settings-drift", {
    description: "List settings.json keys that nix does not own",
    handler: async (_args, ctx) => {
      const entries = loadDrift();
      if (entries === undefined) {
        ctx.ui.notify(
          `settings-drift: cannot read ${NIX_SETTINGS_ENV} or settings.json`,
          "warning",
        );
        return;
      }

      ctx.ui.notify(formatReport(entries), "info");
    },
  });
}

function isJsonObject(value: unknown): value is { [key: string]: JsonValue } {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readJsonFile(path: string): JsonValue | undefined {
  try {
    return JSON.parse(readFileSync(path, "utf8")) as JsonValue;
  } catch {
    return undefined;
  }
}
