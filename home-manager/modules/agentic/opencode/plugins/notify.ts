import type { Plugin } from "@opencode-ai/plugin";

type UnknownRecord = Record<string, unknown>;
type SessionLifecycle = "active" | "idle" | "terminal";

export const NotifyPlugin: Plugin = async ({ $ }) => {
  const notify = async (msg: string, title: string): Promise<void> => {
    await $`notify "${msg}" "${title}"`.quiet().catch(() => {});
  };

  function firstString(...values: unknown[]): string | undefined {
    return values.find(
      (value): value is string => typeof value === "string" && value.length > 0,
    );
  }

  function asRecord(value: unknown): UnknownRecord | undefined {
    return typeof value === "object" && value !== null
      ? (value as UnknownRecord)
      : undefined;
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

  const parents = new Map<string, string>();
  const sessionTitles = new Map<string, string>();
  const sessions = new Map<string, SessionLifecycle>();
  const createdSessions = new Set<string>();
  const notifiedRoots = new Set<string>();

  function resolveRoot(sessionId: string): string {
    const visited = new Set<string>();
    let root = sessionId;

    while (!visited.has(root)) {
      visited.add(root);
      const parent = parents.get(root);
      if (!parent) return root;
      root = parent;
    }

    return sessionId;
  }

  function sessionTitle(sessionId: string | undefined): string {
    const base = sessionId ? sessionTitles.get(sessionId) : undefined;
    if (!base) return "Opencode";
    const prefix = "Opencode - ";
    const max = 40 - prefix.length;
    return prefix + (base.length > max ? base.slice(0, max) + "..." : base);
  }

  function extractSessionStatus(context: unknown): string | undefined {
    const status = asRecord(eventProperties(context)?.status);
    return firstString(status?.type);
  }

  function transitionSession(
    sessionId: string,
    lifecycle: SessionLifecycle,
  ): void {
    if (sessions.get(sessionId) === "terminal" && lifecycle !== "terminal") {
      return;
    }

    sessions.set(sessionId, lifecycle);
    if (lifecycle === "active") {
      notifiedRoots.delete(resolveRoot(sessionId));
    }
  }

  function allSessionsComplete(rootId: string): boolean {
    if (!createdSessions.has(rootId)) return false;

    for (const sessionId of createdSessions) {
      if (resolveRoot(sessionId) !== rootId) continue;
      if (sessions.get(sessionId) === "active") return false;
    }

    return true;
  }

  async function notifyWhenComplete(sessionId: string): Promise<void> {
    const rootId = resolveRoot(sessionId);
    if (!allSessionsComplete(rootId) || notifiedRoots.has(rootId)) return;

    notifiedRoots.add(rootId);
    await notify("task complete", sessionTitle(rootId));
  }

  return {
    event: async (context) => {
      try {
        const event = asRecord(asRecord(context)?.event);
        if (!event) return;

        const type = firstString(event?.type);
        if (!type) return;

        if (type === "session.created") {
          const properties = asRecord(event?.properties);
          const info = asRecord(properties?.info);
          const sessionId = firstString(
            info?.id,
            properties?.sessionID,
            properties?.sessionId,
          );
          if (sessionId) {
            const isNewSession = !createdSessions.has(sessionId);
            createdSessions.add(sessionId);
            const parentId = firstString(
              info?.parentID,
              info?.parentId,
              properties?.parentID,
            );
            if (parentId) {
              parents.set(sessionId, parentId);
            } else {
              parents.delete(sessionId);
            }
            const title = firstString(info?.title);
            if (title) {
              sessionTitles.set(sessionId, title);
            }
            if (!sessions.has(sessionId)) {
              sessions.set(sessionId, "active");
            }
            if (isNewSession) {
              notifiedRoots.delete(resolveRoot(sessionId));
            }
            if (isNewSession && sessions.get(sessionId) !== "terminal") {
              await notifyWhenComplete(sessionId);
            }
          }
          return;
        }

        if (type === "session.updated") {
          const properties = asRecord(event?.properties);
          const info = asRecord(properties?.info);
          const sessionId = firstString(
            info?.id,
            properties?.sessionID,
            properties?.sessionId,
          );
          if (sessionId) {
            const title = firstString(info?.title);
            if (title) {
              sessionTitles.set(sessionId, title);
            }
          }
          return;
        }

        if (type === "session.deleted" || type === "session.error") {
          const sessionId = extractSessionId(context);
          if (!sessionId) return;

          transitionSession(sessionId, "terminal");
          const rootId = resolveRoot(sessionId);
          if (createdSessions.has(rootId) && rootId === sessionId) {
            notifiedRoots.add(rootId);
            if (type === "session.error") {
              await notify("task failed", sessionTitle(rootId));
            }
          }
          return;
        }

        if (type === "session.idle") {
          const sessionId = extractSessionId(context);
          if (!sessionId) return;

          transitionSession(sessionId, "idle");
          await notifyWhenComplete(sessionId);
          return;
        }

        if (type === "session.status") {
          const sessionId = extractSessionId(context);
          if (!sessionId) return;

          switch (extractSessionStatus(context)) {
            case "busy":
            case "retry":
              transitionSession(sessionId, "active");
              return;
            case "idle":
              transitionSession(sessionId, "idle");
              await notifyWhenComplete(sessionId);
              return;
          }
          return;
        }

        const map = {
          "permission.asked": "needs permission",
          "question.asked": "has a question",
        } as const;

        const msg = map[type as keyof typeof map];
        if (!msg) return;

        const sessionId = extractSessionId(context);
        if (
          sessionId &&
          createdSessions.has(sessionId) &&
          resolveRoot(sessionId) === sessionId
        ) {
          await notify(msg, sessionTitle(sessionId));
        }
      } catch {
        // Notifications are best-effort; never interrupt opencode.
      }
    },
  };
};
