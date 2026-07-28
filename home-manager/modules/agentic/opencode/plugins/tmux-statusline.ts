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
type RootLifecycle = "active" | "terminal";
type SessionLifecycle = "active" | "idle" | "terminal";
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

  // The latest root chat owns the window. Its known descendants contribute both
  // lifecycle and blocker state to the pinned window's aggregate indicator.
  const parents = new Map<string, string>();
  const createdSessions = new Set<string>();
  const sessions = new Map<string, SessionLifecycle>();
  const blockers = new Set<string>();
  let activeRoot: string | undefined;
  // Terminal roots remain selected but inactive, so delayed descendant events
  // cannot revive an indicator after the root errors or is deleted.
  let rootLifecycle: RootLifecycle = "active";
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

  function belongsToSelectedRoot(sessionId: string): boolean {
    return activeRoot !== undefined && resolveRoot(sessionId) === activeRoot;
  }

  function hasTerminalAncestor(sessionId: string): boolean {
    const visited = new Set<string>();
    let current = sessionId;

    while (!visited.has(current)) {
      visited.add(current);
      const parent = parents.get(current);
      if (!parent) return false;
      if (sessions.get(parent) === "terminal") return true;
      current = parent;
    }

    return false;
  }

  function isActiveSession(sessionId: string): boolean {
    // A terminal session (or ancestor) retires its subtree. Idle sessions also
    // reject late work and blocker requests, while allowing blocker resolution.
    return (
      rootLifecycle === "active" &&
      belongsToSelectedRoot(sessionId) &&
      sessions.get(sessionId) === "active" &&
      !hasTerminalAncestor(sessionId)
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

  function retireSubtree(sessionId: string): void {
    const pending = [sessionId];
    const retired = new Set<string>();

    while (pending.length > 0) {
      const current = pending.pop();
      if (!current || retired.has(current)) continue;

      retired.add(current);
      sessions.set(current, "terminal");
      removeSessionBlockers(current);

      for (const [child, parent] of parents) {
        if (parent === current) pending.push(child);
      }
    }
  }

  function hasActiveSessions(): boolean {
    for (const [sessionId, lifecycle] of sessions) {
      if (lifecycle === "active" && isActiveSession(sessionId)) return true;
    }

    return false;
  }

  function desiredState(): DesiredState {
    if (!activeRoot || rootLifecycle !== "active") return "clear";
    // Questions require a direct user answer, so surface them ahead of a
    // concurrent permission request for the same active root.
    if ([...blockers].some((blocker) => blocker.startsWith("question\u0000"))) {
      return "question";
    }
    if ([...blockers].some((blocker) => blocker.startsWith("permission\u0000"))) {
      return "permission";
    }
    return hasActiveSessions() ? "working" : "clear";
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
    rootLifecycle = "active";
    sessions.set(activeRoot, "active");
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
    const lifecycle = sessions.get(sessionId);
    if (
      rootLifecycle !== "active" ||
      !belongsToSelectedRoot(sessionId) ||
      lifecycle === "terminal" ||
      hasTerminalAncestor(sessionId) ||
      (action === "asked" && lifecycle !== "active")
    ) {
      return effects;
    }

    const key = blockerKey(kind, sessionId, requestId);
    if (action === "asked") blockers.add(key);
    else blockers.delete(key);
    return render(context);
  }

  function transitionSession(
    sessionId: string,
    nextLifecycle: Exclude<SessionLifecycle, "active">,
    context: string,
  ): Promise<void> {
    if (nextLifecycle === "terminal") {
      if (sessions.get(sessionId) === "terminal") return effects;

      const endsActiveRoot =
        sessionId === activeRoot && rootLifecycle === "active";
      retireSubtree(sessionId);
      if (endsActiveRoot) {
        rootLifecycle = "terminal";
        blockers.clear();
      }

      return endsActiveRoot ||
        (rootLifecycle === "active" &&
          belongsToSelectedRoot(sessionId) &&
          !hasTerminalAncestor(sessionId))
        ? render(context)
        : effects;
    }

    if (sessions.get(sessionId) === "terminal" || sessions.get(sessionId) === "idle") {
      return effects;
    }

    sessions.set(sessionId, "idle");
    return rootLifecycle === "active" &&
      belongsToSelectedRoot(sessionId) &&
      !hasTerminalAncestor(sessionId)
      ? render(context)
      : effects;
  }

  function recordSession(context: unknown): Promise<void> {
    const properties = eventProperties(context);
    const info = asRecord(properties?.info);
    const sessionId = firstString(info?.id, properties?.sessionID, properties?.sessionId);
    if (!sessionId) return effects;
    if (createdSessions.has(sessionId)) return effects;

    const parentId = firstString(info?.parentID, info?.parentId, properties?.parentID);
    createdSessions.add(sessionId);
    if (parentId) {
      parents.set(sessionId, parentId);
    } else {
      parents.delete(sessionId);
    }

    if (!sessions.has(sessionId)) {
      sessions.set(
        sessionId,
        hasTerminalAncestor(sessionId) ? "terminal" : "active",
      );
    }
    return isActiveSession(sessionId) ? render("session.created") : effects;
  }

  async function handleEvent(context: unknown): Promise<void> {
    // Generic events are the lifecycle authority because they include terminal
    // and blocker transitions. Typed hooks below remain compatibility adapters
    // for hook paths that do not emit an equivalent generic event.
    const type = firstString(asRecord(asRecord(context)?.event)?.type);
    if (!type) return;

    if (type === "session.created") {
      await recordSession(context);
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
        switch (extractSessionStatus(context)) {
          case "busy":
          case "retry":
            if (isActiveSession(sessionId)) await render(type);
            return;
          case "idle":
            await transitionSession(sessionId, "idle", type);
            return;
        }
        return;
      case "session.idle":
        await transitionSession(sessionId, "idle", type);
        return;
      case "session.error":
      case "session.deleted":
        await transitionSession(sessionId, "terminal", type);
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
