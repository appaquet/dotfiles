// Source: https://github.com/ankarhem/opencode-direnv
// Branch: feat/auto-reload-devshell
// Commit: d902c6fc7efe74ed673fc147bcccd6290f858385
// Fork of https://github.com/simonwjackson/opencode-direnv (PR #3)
//
// Diverges from upstream: this copy applies `direnv export json` as a sparse
// patch. Upstream treats each export as a full snapshot and deletes keys absent
// from it, which drops the inherited Home Manager/fish PATH. Re-apply when
// re-vendoring.

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
 * - On file.watcher.updated for direnv's evaluated watch set: debounced reload
 * - Applies each `direnv export json` result as a sparse patch to process.env
 *   (explicit null values remove variables; omitted keys are left untouched)
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
  /** direnv not installed or no .envrc found */
  unavailable: boolean
  /** a transient error occurred talking to direnv */
  error: boolean
  /** number of brand-new variables added to process.env */
  added: number
  /** number of existing variables whose value changed */
  changed: number
  /** number of variables explicitly removed by the patch */
  removed: number
  /** number of entries in the most recent direnv patch */
  patched: number
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
  env: (env: Record<string, string | undefined>) => ShellCommand
  text: () => Promise<string>
}

type ShellExecutor = (
  strings: TemplateStringsArray,
  ...values: unknown[]
) => ShellCommand

type ShellError = Error & { stderr?: string }

/** fallback devshell filenames whose modification should trigger a reload */
const RELEVANT_FILES = new Set([".envrc", "flake.nix", "flake.lock"])

/** debounce window for background reloads (ms) */
const RELOAD_DEBOUNCE_MS = 1500

export const DirenvLoader: Plugin = async ({ client, $, directory }) => {
  const loadedSessions = new Set<string>()
  const typedClient = client as unknown as SessionClient
  const shell = $ as unknown as ShellExecutor

  /** cached .envrc location (only cached once successfully found) */
  let envrcDir: string | null = null
  let discovered = false

  /** evaluated direnv dependencies; null preserves the hardcoded fallback */
  let watchedPaths: Set<string> | null = null

  /** in-flight export; later callers chain a fresh run after it */
  let inFlight: Promise<ReloadOutcome> | null = null

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
   * Find git root directory for the plugin's directory, if one exists.
   * Resolved against `directory` so the boundary matches where the .envrc
   * search starts, regardless of the host process's cwd.
   */
  const findGitRoot = async (): Promise<string | null> => {
    try {
      const result = await shell`git rev-parse --show-toplevel`
        .cwd(directory)
        .quiet()
        .text()
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
    patched: 0,
  })

  /**
   * Replace the evaluated direnv watch set after a successful export.
   *
   * `watch-print --null` is intentionally queried only after the export patch
   * has updated process.env: direnv reads the current DIRENV_WATCHES value.
   * Discovery errors do not invalidate that export; they select the legacy
   * basename fallback until a later successful export can discover a new set.
   */
  const refreshWatchSet = async (dir: string) => {
    try {
      const output = await shell`direnv watch-print --null`
        .cwd(dir)
        .env({ ...process.env })
        .quiet()
        .text()
      const { isAbsolute, normalize } = await import("node:path")
      const paths = output.split("\0")
      const trailing = paths.pop()

      if (
        trailing !== "" ||
        paths.length === 0 ||
        paths.some((path) => !path || !isAbsolute(path))
      ) {
        watchedPaths = null
        return
      }

      watchedPaths = new Set(paths.map(normalize))
    } catch {
      watchedPaths = null
    }
  }

  /** Normalize an event path for exact comparison with direnv's absolute paths. */
  const normalizeEventPath = async (file: string) => {
    const { isAbsolute, normalize, resolve } = await import("node:path")
    return normalize(isAbsolute(file) ? file : resolve(directory, file))
  }

  /** Select dynamic exact matching or the hardcoded compatibility fallback. */
  const shouldReloadFor = async (file: string) => {
    if (watchedPaths) {
      return watchedPaths.has(await normalizeEventPath(file))
    }

    const filename = file.split("/").pop() ?? ""
    return RELEVANT_FILES.has(filename)
  }

  /**
   * Run `direnv export json` once and apply its sparse patch to process.env.
   * Returns a summary describing what (if anything) changed.
   */
  const runExport = async (): Promise<ReloadOutcome> => {
    const outcome = newOutcome()

    try {
      const dir = await resolveEnvrcDir()
      if (!dir) {
        outcome.unavailable = true
        return outcome
      }

      let jsonText: string
      try {
        jsonText = await shell`direnv export json`
          .cwd(dir)
          .env({ ...process.env })
          .quiet()
          .text()
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
      const patch: Record<string, string | null> =
        parsed && typeof parsed === "object" ? parsed : {}
      const entries = Object.entries(patch)
      outcome.patched = entries.length

      for (const [key, value] of entries) {
        if (value === null) {
          if (key in process.env) {
            delete process.env[key]
            outcome.removed++
          }
          continue
        }

        const current = process.env[key]
        if (current === undefined) outcome.added++
        else if (current !== value) outcome.changed++
        process.env[key] = value
      }

      await refreshWatchSet(dir)
      return outcome
    } catch {
      outcome.error = true
      return outcome
    }
  }

  /**
   * Serialized reload, safe to call from any trigger.
   *
   * A caller arriving while an export is in flight waits for a fresh export
   * chained after it rather than being dropped: that in-flight export may
   * predate whatever triggered this call, so its result cannot be reused. This
   * keeps direnv invocations non-overlapping while guaranteeing an awaited
   * initial load never returns before the environment has been applied.
   *
   * Cheap when nothing changed (direnv's own watch cache makes the export
   * ~milliseconds), and debouncing collapses trigger bursts before they reach
   * here, so the chain stays short.
   */
  const reloadEnv = async (): Promise<ReloadOutcome> => {
    const run = inFlight
      ? inFlight.catch(() => {}).then(runExport)
      : runExport()
    inFlight = run

    try {
      return await run
    } finally {
      if (inFlight === run) inFlight = null
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
      if (total > 0 || outcome.patched > 0) {
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

      // Tracked devshell file edited/created/deleted -> reload (debounced).
      if (event.type === "file.watcher.updated") {
        const typedEvent = event as FileWatcherUpdatedEvent
        if (await shouldReloadFor(typedEvent.properties.file)) {
          scheduleReload(RELOAD_DEBOUNCE_MS)
        }
        return
      }
    },
  }
}
