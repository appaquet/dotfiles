import type { Plugin } from "@opencode-ai/plugin";

// Reflect lifecycle state only in the window that started this OpenCode process.
// Callbacks can arrive after the user changes tmux windows, so following the
// current window would overwrite the status of an unrelated task.

const statusline = {
  clear: undefined,
  working: "🔄",
  permission: "🔐",
  question: "❓",
} as const;

type DesiredState = keyof typeof statusline;
type Lifecycle = "active" | "idle" | "terminal";
type BlockerKind = "permission" | "question";
type UnknownRecord = Record<string, unknown>;

const tmuxStatusline = "tmux-statusline";

export const TmuxStatuslinePlugin: Plugin = async ({ client, $ }) => {
  async function logFailure(context: string, error: unknown): Promise<void> {
    const detail = error instanceof Error ? error.message : String(error);

    try {
      await client.app.log({
        body: {
          service: "tmux-statusline",
          level: "error",
          message: `${context}: ${detail}`,
        },
      });
    } catch {
      // Logging failures must not interrupt OpenCode hooks either.
    }
  }

  let windowId: string;
  try {
    // Initialization clears stale state and returns the window in which this
    // OpenCode process started, keeping later lifecycle calls pinned there.
    windowId = (await $`${tmuxStatusline} init`.quiet().text()).trim();
    if (!windowId) return {};
  } catch (error) {
    await logFailure("initialization", error);
    return {};
  }

  // The latest root chat owns the window. Descendants can contribute blockers,
  // but only their root can clear the indicator when its chat lifecycle ends.
  const parents = new Map<string, string>();
  const blockers = new Set<string>();
  let activeRoot: string | undefined;
  // Terminal roots remain selected but inactive, so delayed blocker and tool
  // callbacks cannot revive an indicator after the root errors or is deleted.
  let lifecycle: Lifecycle = "idle";
  let lastRequested: DesiredState | undefined;
  // Hooks can overlap. Serialize tmux mutations in reducer order so newer
  // state wins, and avoid spawning duplicate effects for the same state.
  let effects: Promise<void> = Promise.resolve();

  function asRecord(value: unknown): UnknownRecord | undefined {
    return typeof value === "object" && value !== null
      ? (value as UnknownRecord)
      : undefined;
  }

  function firstString(...values: unknown[]): string | undefined {
    return values.find(
      (value): value is string => typeof value === "string" && value.length > 0,
    );
  }

  function eventProperties(context: unknown): UnknownRecord | undefined {
    const event = asRecord(asRecord(context)?.event);
    return asRecord(event?.properties);
  }

  function extractSessionId(context: unknown): string | undefined {
    const input = asRecord(context);
    const properties = eventProperties(context);
    const info = asRecord(properties?.info);

    return firstString(
      properties?.sessionID,
      properties?.sessionId,
      info?.id,
      input?.sessionID,
      input?.sessionId,
    );
  }

  function extractRequestId(context: unknown): string | undefined {
    const hookInput = asRecord(asRecord(context)?.input);
    const input = asRecord(context);
    const properties = eventProperties(context);

    return firstString(
      properties?.permissionID,
      properties?.permissionId,
      properties?.id,
      properties?.requestID,
      properties?.requestId,
      input?.permissionID,
      input?.permissionId,
      input?.requestID,
      input?.requestId,
      hookInput?.permissionID,
      hookInput?.permissionId,
      hookInput?.requestID,
      hookInput?.requestId,
    );
  }

  function extractSessionStatus(context: unknown): string | undefined {
    return firstString(asRecord(eventProperties(context)?.status)?.type);
  }

  function resolveRoot(sessionId: string): string {
    const visited = new Set<string>();
    let root = sessionId;

    // Event payloads can be partial or malformed; stop on a cycle rather than
    // letting a bad parent graph block every subsequent lifecycle callback.
    while (!visited.has(root)) {
      visited.add(root);
      const parent = parents.get(root);
      if (!parent) return root;
      root = parent;
    }

    return sessionId;
  }

  function isActiveSession(sessionId: string): boolean {
    // Lifecycle is part of ownership: terminal and idle roots ignore late
    // descendant updates instead of restoring a stale statusline.
    return (
      activeRoot !== undefined &&
      lifecycle === "active" &&
      resolveRoot(sessionId) === activeRoot
    );
  }

  function blockerKey(
    kind: BlockerKind,
    sessionId: string,
    requestId: string | undefined,
  ): string {
    // Typed hooks and generic events may report one request twice. A shared
    // kind/session/request key makes those reports idempotent; the stable
    // fallback treats unknown IDs for the same blocker kind/session as one.
    return `${kind}\u0000${sessionId}\u0000${requestId ?? "__tmux_statusline_fallback__"}`;
  }

  function removeSessionBlockers(sessionId: string): void {
    const suffix = `\u0000${sessionId}\u0000`;
    for (const blocker of blockers) {
      if (blocker.includes(suffix)) blockers.delete(blocker);
    }
  }

  function desiredState(): DesiredState {
    if (!activeRoot || lifecycle !== "active") return "clear";
    // Questions require a direct user answer, so surface them ahead of a
    // concurrent permission request for the same active root.
    if ([...blockers].some((blocker) => blocker.startsWith("question\u0000"))) {
      return "question";
    }
    if ([...blockers].some((blocker) => blocker.startsWith("permission\u0000"))) {
      return "permission";
    }
    return "working";
  }

  async function applyStatusline(
    state: DesiredState,
    context: string,
  ): Promise<void> {
    try {
      if (state === "clear") {
        await $`TMUX_WINDOW_ID=${windowId} ${tmuxStatusline} clear`.quiet();
      } else {
        await $`TMUX_WINDOW_ID=${windowId} ${tmuxStatusline} set ${statusline[state]}`.quiet();
      }
    } catch (error) {
      if (lastRequested === state) lastRequested = undefined;
      // Presentation failures do not change lifecycle state; a later event can
      // retry the desired title without interrupting OpenCode.
      await logFailure(`${context} (${state})`, error);
    }
  }

  function render(context: string, force = false): Promise<void> {
    const state = desiredState();
    if (!force && state === lastRequested) return effects;

    lastRequested = state;
    effects = effects.then(() => applyStatusline(state, context));
    return effects;
  }

  function selectRoot(sessionId: string): Promise<void> {
    activeRoot = resolveRoot(sessionId);
    lifecycle = "active";
    blockers.clear();
    return render("chat.message");
  }

  function updateBlocker(
    sessionId: string,
    kind: BlockerKind,
    requestId: string | undefined,
    action: "asked" | "resolved",
    context: string,
  ): Promise<void> {
    if (!isActiveSession(sessionId)) return effects;

    const key = blockerKey(kind, sessionId, requestId);
    if (action === "asked") blockers.add(key);
    else blockers.delete(key);
    return render(context);
  }

  function finishRoot(
    sessionId: string,
    nextLifecycle: Exclude<Lifecycle, "active">,
    context: string,
  ): Promise<void> {
    if (sessionId !== activeRoot) return effects;

    lifecycle = nextLifecycle;
    blockers.clear();
    return render(context);
  }

  function recordSession(context: unknown): void {
    const properties = eventProperties(context);
    const info = asRecord(properties?.info);
    const sessionId = firstString(info?.id, properties?.sessionID, properties?.sessionId);
    if (!sessionId) return;

    const parentId = firstString(info?.parentID, info?.parentId, properties?.parentID);
    if (parentId) {
      parents.set(sessionId, parentId);
    } else {
      parents.delete(sessionId);
    }
  }

  async function handleEvent(context: unknown): Promise<void> {
    // Generic events are the lifecycle authority because they include terminal
    // and blocker transitions. Typed hooks below remain compatibility adapters
    // for hook paths that do not emit an equivalent generic event.
    const type = firstString(asRecord(asRecord(context)?.event)?.type);
    if (!type) return;

    if (type === "session.created") {
      recordSession(context);
      return;
    }

    const sessionId = extractSessionId(context);
    if (!sessionId) return;

    switch (type) {
      case "permission.asked":
        await updateBlocker(sessionId, "permission", extractRequestId(context), "asked", type);
        return;
      case "question.asked":
        await updateBlocker(sessionId, "question", extractRequestId(context), "asked", type);
        return;
      case "permission.replied":
      case "permission.rejected":
        await updateBlocker(sessionId, "permission", extractRequestId(context), "resolved", type);
        return;
      case "question.replied":
      case "question.rejected":
        await updateBlocker(sessionId, "question", extractRequestId(context), "resolved", type);
        return;
      case "session.status":
        if (extractSessionStatus(context) === "idle") {
          await finishRoot(sessionId, "idle", type);
        }
        return;
      case "session.idle":
        await finishRoot(sessionId, "idle", type);
        return;
      case "session.error":
        await finishRoot(sessionId, "terminal", type);
        return;
      case "session.deleted":
        if (sessionId === activeRoot) {
          await finishRoot(sessionId, "terminal", type);
        } else {
          const wasActiveDescendant = isActiveSession(sessionId);
          removeSessionBlockers(sessionId);
          parents.delete(sessionId);
          if (wasActiveDescendant) await render(type);
        }
    }
  }

  async function safely(context: string, operation: () => Promise<void>): Promise<void> {
    try {
      await operation();
    } catch (error) {
      // Statusline tracking is best-effort: malformed hook payloads and failed
      // utilities must never interrupt OpenCode's own lifecycle.
      await logFailure(context, error);
    }
  }

  return {
    event: async (context) => safely("event", () => handleEvent(context)),

    // Keep these narrow adapters alongside generic events for OpenCode versions
    // or hook paths where the corresponding lifecycle event is unavailable.
    "chat.message": async (input) =>
      safely("chat.message", async () => {
        const sessionId = extractSessionId(input);
        if (sessionId) await selectRoot(sessionId);
      }),

    "tool.execute.after": async (input) =>
      safely("tool.execute.after", async () => {
        const sessionId = extractSessionId(input);
        if (sessionId && isActiveSession(sessionId)) {
          await render("tool.execute.after");
        }
      }),

    "permission.ask": async (input) =>
      safely("permission.ask", async () => {
        const sessionId = extractSessionId(input);
        if (sessionId) {
          await updateBlocker(
            sessionId,
            "permission",
            extractRequestId(input),
            "asked",
            "permission.ask",
          );
        }
      }),
  };
};
