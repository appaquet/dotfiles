// Source: https://github.com/ankarhem/opencode-direnv
// Branch: feat/auto-reload-devshell
// Commit: d902c6fc7efe74ed673fc147bcccd6290f858385
// Fork of https://github.com/simonwjackson/opencode-direnv (PR #3)

import type { Plugin } from "@opencode-ai/plugin"

/**
 * Direnv Auto-Loader Plugin for OpenCode
 *
 * Automatically loads AND keeps in sync environment variables from direnv.
 * Bash commands run by the agent always see the current devshell state, even
 * after the user edits .envrc/flake.nix or runs `direnv reload` mid-session.
 *
 * Behavior:
 * - On session.created: load env once (awaited, so the first command is ready)
 * - On file.watcher.updated for .envrc/flake.nix/flake.lock: debounced reload
 * - Reloads diff against the previously applied vars and *remove* dropped keys
 *   from process.env (so removed variables don't linger)
 * - Shows toast notifications for blocked .envrc, successful loads and changes
 * - Silently skips if direnv is not installed or .envrc is missing
 */

type ToastVariant = "info" | "success" | "warning" | "error"

type SessionClient = {
  tui: {
    showToast: (opts: {
      body: { message: string; variant: ToastVariant }
    }) => Promise<void>
  }
}

type ReloadOutcome = {
  /** .envrc exists but is blocked (`direnv allow` needed) */
  blocked: boolean
  /** direnv not installed / no .envrc / discovery failed */
  unavailable: boolean
  /** a transient error occurred talking to direnv */
  error: boolean
  /** number of brand-new variables added to process.env */
  added: number
  /** number of existing variables whose value changed */
  changed: number
  /** number of previously-applied variables that were removed */
  removed: number
}

type SessionCreatedEvent = {
  type: "session.created"
  properties: { info: { id: string } }
}

type FileWatcherUpdatedEvent = {
  type: "file.watcher.updated"
  properties: { file: string; event: "add" | "change" | "unlink" }
}

type ShellCommand = {
  quiet: () => ShellCommand
  cwd: (dir: string) => ShellCommand
  text: () => Promise<string>
}

type ShellExecutor = (
  strings: TemplateStringsArray,
  ...values: unknown[]
) => ShellCommand

type ShellError = Error & { stderr?: string }

/** devshell files whose modification should trigger a reload */
const RELEVANT_FILES = new Set([".envrc", "flake.nix", "flake.lock"])

/** debounce window for background reloads (ms) */
const RELOAD_DEBOUNCE_MS = 1500

export const DirenvLoader: Plugin = async ({ client, $, directory }) => {
  const loadedSessions = new Set<string>()
  const typedClient = client as unknown as SessionClient
  const shell = $ as unknown as ShellExecutor

  /**
   * Keys we have written into process.env. Tracked globally (process.env is
   * shared across sessions in the plugin process) so reloads can remove vars
   * that the devshell no longer exports without touching anything we didn't set.
   */
  const appliedKeys = new Set<string>()

  /** cached .envrc location (only cached once successfully found) */
  let envrcDir: string | null = null
  let discovered = false

  /** prevents overlapping `direnv export json` invocations */
  let reloading = false

  let reloadTimer: ReturnType<typeof setTimeout> | null = null
  let firstLoadComplete = false

  const showToast = async (message: string, variant: ToastVariant) => {
    try {
      await typedClient.tui.showToast({ body: { message, variant } })
    } catch {
      // toast failures are non-fatal
    }
  }

  /**
   * Find git root directory, if one exists
   */
  const findGitRoot = async (): Promise<string | null> => {
    try {
      const result = await shell`git rev-parse --show-toplevel`.quiet().text()
      return result.trim() || null
    } catch {
      return null
    }
  }

  /**
   * Find .envrc file searching from directory up to stopAt (git root or filesystem root)
   */
  const findEnvrc = async (
    startDir: string,
    stopAt: string | null
  ): Promise<string | null> => {
    const { dirname, join } = await import("node:path")
    const { existsSync } = await import("node:fs")

    let current = startDir
    const boundary = stopAt || "/"

    while (true) {
      const envrcPath = join(current, ".envrc")
      if (existsSync(envrcPath)) {
        return envrcPath
      }

      if (current === boundary || current === "/") {
        break
      }

      const parent = dirname(current)
      if (parent === current) {
        break
      }

      current = parent
    }

    return null
  }

  /**
   * Resolve (and cache) the directory containing .envrc.
   * Caches only on success; a missing .envrc is re-checked on later triggers
   * so one created mid-session is eventually picked up.
   */
  const resolveEnvrcDir = async (): Promise<string | null> => {
    if (discovered) return envrcDir
    const gitRoot = await findGitRoot()
    const envrcPath = await findEnvrc(directory, gitRoot)
    if (envrcPath) {
      const { dirname } = await import("node:path")
      envrcDir = dirname(envrcPath)
    }
    discovered = envrcDir !== null
    return envrcDir
  }

  const newOutcome = (): ReloadOutcome => ({
    blocked: false,
    unavailable: false,
    error: false,
    added: 0,
    changed: 0,
    removed: 0,
  })

  /**
   * Re-run `direnv export json` and reconcile process.env.
   *
   * Idempotent and mutex-guarded: safe to call from any trigger. Cheap when
   * nothing changed (direnv's own watch cache makes the export ~milliseconds).
   * Returns a summary describing what (if anything) changed.
   */
  const reloadEnv = async (): Promise<ReloadOutcome> => {
    const outcome = newOutcome()
    if (reloading) return outcome
    reloading = true

    try {
      const dir = await resolveEnvrcDir()
      if (!dir) {
        outcome.unavailable = true
        return outcome
      }

      let jsonText: string
      try {
        jsonText = await shell`direnv export json`.cwd(dir).quiet().text()
      } catch (error: unknown) {
        const stderr =
          error && typeof error === "object" && "stderr" in error
            ? String((error as ShellError).stderr ?? "")
            : ""
        if (stderr.includes("is blocked")) {
          outcome.blocked = true
        } else {
          outcome.error = true
        }
        return outcome
      }

      const parsed = jsonText.trim() ? JSON.parse(jsonText) : {}
      const newVars: Record<string, string> =
        parsed && typeof parsed === "object" ? parsed : {}

      // 1. Remove vars we previously applied that the devshell no longer exports.
      //    direnv may also emit explicit `null` values to signal unsets.
      for (const key of appliedKeys) {
        const keep = key in newVars && newVars[key] != null
        if (!keep && key in process.env) {
          delete process.env[key]
          outcome.removed++
        }
      }

      // 2. Apply current vars, counting additions and value changes.
      const nextApplied = new Set<string>()
      for (const [key, value] of Object.entries(newVars)) {
        if (value == null) continue
        const current = process.env[key]
        if (current === undefined) outcome.added++
        else if (current !== value) outcome.changed++
        process.env[key] = value
        nextApplied.add(key)
      }

      appliedKeys.clear()
      for (const key of nextApplied) appliedKeys.add(key)

      return outcome
    } catch {
      outcome.error = true
      return outcome
    } finally {
      reloading = false
    }
  }

  /**
   * Surface a reload result via toast.
   *
   * - blocked: always warn (action required by the user)
   * - first load: confirm the environment was applied
   * - subsequent: only notify when something actually changed
   * - no-op / unavailable / transient error: silent
   */
  const notify = (outcome: ReloadOutcome, opts: { initial: boolean }) => {
    if (outcome.blocked) {
      void showToast(
        "direnv: .envrc is blocked. Run `direnv allow` to enable.",
        "warning"
      )
      return
    }
    if (outcome.unavailable || outcome.error) return

    const total = outcome.added + outcome.changed + outcome.removed

    if (opts.initial && !firstLoadComplete) {
      firstLoadComplete = true
      if (total > 0 || appliedKeys.size > 0) {
        void showToast("direnv: environment loaded", "info")
      }
      return
    }

    if (total > 0) {
      const parts: string[] = []
      if (outcome.added) parts.push(`+${outcome.added}`)
      if (outcome.changed) parts.push(`~${outcome.changed}`)
      if (outcome.removed) parts.push(`-${outcome.removed}`)
      void showToast(`direnv: reloaded (${parts.join(" ")})`, "info")
    }
  }

  /**
   * Run a reload in the background, detached from the event loop so a slow
   * `use flake` re-evaluation can never block opencode's event processing.
   */
  const reloadInBackground = async () => {
    const outcome = await reloadEnv()
    notify(outcome, { initial: false })
  }

  /**
   * Debounced background reload. Collapses rapid triggers (e.g. many file
   * writes from an editor save) into a single reload.
   */
  const scheduleReload = (delayMs: number) => {
    if (reloadTimer) clearTimeout(reloadTimer)
    reloadTimer = setTimeout(() => {
      reloadTimer = null
      void reloadInBackground()
    }, delayMs)
  }

  return {
    event: async ({ event }) => {
      // Initial load: awaited so the first command in the session sees the env.
      if (event.type === "session.created") {
        const typedEvent = event as SessionCreatedEvent
        const sessionID = typedEvent.properties.info.id

        if (!loadedSessions.has(sessionID)) {
          loadedSessions.add(sessionID)
          const outcome = await reloadEnv()
          notify(outcome, { initial: true })
        }
        return
      }

      // Devshell file edited/created/deleted -> reload (debounced).
      if (event.type === "file.watcher.updated") {
        const typedEvent = event as FileWatcherUpdatedEvent
        const filename = typedEvent.properties.file.split("/").pop() ?? ""
        if (RELEVANT_FILES.has(filename)) {
          scheduleReload(RELOAD_DEBOUNCE_MS)
        }
        return
      }
    },
  }
}