import { expect, test } from "bun:test";

import { TmuxStatuslinePlugin } from "./tmux-statusline";

type ShellCommand = {
  quiet: () => ShellCommand;
  text: () => Promise<string>;
};

type CommandRunner = {
  commands: string[];
  tag: (strings: TemplateStringsArray, ...values: unknown[]) => ShellCommand;
};

type DeferredCommandRunner = CommandRunner & {
  completions: string[];
  resolveNext: () => void;
  waitForPending: () => Promise<void>;
};

type Hooks = {
  event: (context: unknown) => Promise<void>;
  "chat.message": (input: unknown) => Promise<void>;
};

type TestHarness = {
  commands: string[];
  hooks: Hooks;
  logs: unknown[];
};

const windowId = "window-7";

function createCommandRunner(
  failureFor?: (command: string) => Error | undefined,
): CommandRunner {
  const commands: string[] = [];

  const tag = (strings: TemplateStringsArray, ...values: unknown[]) => {
    const command = strings.reduce(
      (result, string, index) =>
        `${result}${string}${index < values.length ? String(values[index]) : ""}`,
      "",
    );
    commands.push(command);

    const shellCommand: ShellCommand = {
      quiet: () => {
        const error = failureFor?.(command);
        if (error) throw error;
        return shellCommand;
      },
      text: async () => {
        if (command === "tmux-statusline init") return windowId;
        throw new Error(`Unexpected text command: ${command}`);
      },
    };
    return shellCommand;
  };

  return { commands, tag };
}

function createDeferredCommandRunner(): DeferredCommandRunner {
  const commands: string[] = [];
  const completions: string[] = [];
  const pending: (() => void)[] = [];
  const waiters: (() => void)[] = [];

  const tag = (strings: TemplateStringsArray, ...values: unknown[]) => {
    const command = strings.reduce(
      (result, string, index) =>
        `${result}${string}${index < values.length ? String(values[index]) : ""}`,
      "",
    );
    commands.push(command);

    const shellCommand: ShellCommand & { then: PromiseLike<void>["then"] } = {
      quiet: () => shellCommand,
      text: async () => {
        if (command === "tmux-statusline init") return windowId;
        throw new Error(`Unexpected text command: ${command}`);
      },
      then: (onfulfilled, onrejected) =>
        new Promise<void>((resolve) => {
          pending.push(() => {
            completions.push(command);
            resolve();
          });
          for (const notify of waiters.splice(0)) notify();
        }).then(onfulfilled, onrejected),
    };
    return shellCommand;
  };

  return {
    commands,
    completions,
    tag,
    resolveNext: () => {
      const resolve = pending.shift();
      if (!resolve) throw new Error("No deferred command is pending");
      resolve();
    },
    waitForPending: () =>
      pending.length > 0
        ? Promise.resolve()
        : new Promise((resolve) => waiters.push(resolve)),
  };
}

async function createHarness(
  runner: CommandRunner = createCommandRunner(),
): Promise<TestHarness> {
  const logs: unknown[] = [];
  const hooks = (await TmuxStatuslinePlugin({
    client: {
      app: {
        log: async (entry: unknown) => {
          logs.push(entry);
        },
      },
    },
    $: runner.tag,
  } as never)) as unknown as Hooks;

  expect(runner.commands).toEqual(["tmux-statusline init"]);
  expect(logs).toEqual([]);

  return { commands: runner.commands, hooks, logs };
}

async function selectRoot(hooks: Hooks, sessionID: string): Promise<void> {
  await hooks["chat.message"]({ sessionID });
}

async function emit(hooks: Hooks, context: unknown): Promise<void> {
  await hooks.event(context);
}

function sessionCreated(sessionID: string, parentID?: string): unknown {
  return {
    event: {
      type: "session.created",
      properties: {
        info: {
          id: sessionID,
          ...(parentID ? { parentID } : {}),
        },
      },
    },
  };
}

function sessionStatus(
  sessionID: string,
  status: "busy" | "retry" | "idle",
): unknown {
  return {
    event: {
      type: "session.status",
      properties: {
        sessionID,
        status: { type: status },
      },
    },
  };
}

function lifecycleEvent(type: string, sessionID: string): unknown {
  return {
    event: {
      type,
      properties: { sessionID },
    },
  };
}

function blockerEvent(
  type: string,
  sessionID: string,
  requestID: string,
): unknown {
  return {
    event: {
      type,
      properties: { sessionID, id: requestID },
    },
  };
}

function expectCommands(commands: string[], ...expected: string[]): void {
  expect(commands).toEqual(["tmux-statusline init", ...expected]);
}

const working = `TMUX_WINDOW_ID=${windowId} tmux-statusline set 🔄`;
const question = `TMUX_WINDOW_ID=${windowId} tmux-statusline set ❓`;
const permission = `TMUX_WINDOW_ID=${windowId} tmux-statusline set 🔐`;
const clear = `TMUX_WINDOW_ID=${windowId} tmux-statusline clear`;

test("keeps working status when the root idles before an active child", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("child", "root"));
  await emit(hooks, sessionStatus("child", "busy"));
  await emit(hooks, sessionStatus("root", "idle"));

  expectCommands(commands, working);
});

test("clears only after the root and every descendant are idle or terminal", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("idle-child", "root"));
  await emit(hooks, sessionCreated("terminal-child", "root"));
  await emit(hooks, sessionStatus("root", "idle"));
  expectCommands(commands, working);

  await emit(hooks, sessionStatus("idle-child", "idle"));
  await emit(hooks, lifecycleEvent("session.error", "terminal-child"));
  expectCommands(commands, working, clear);
});

test("treats multiple descendants and retry as active work", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("retry-child", "root"));
  await emit(hooks, sessionCreated("busy-child", "root"));
  await emit(hooks, sessionStatus("retry-child", "retry"));
  await emit(hooks, sessionStatus("busy-child", "busy"));
  await emit(hooks, sessionStatus("root", "idle"));
  expectCommands(commands, working);
});

test("does not clear during the child-created before child-busy race", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("new-child", "root"));
  await emit(hooks, sessionStatus("root", "idle"));
  expectCommands(commands, working);

  await emit(hooks, sessionStatus("new-child", "busy"));
  expectCommands(commands, working);
});

test("does not reparent known sessions on duplicate creation", async () => {
  const { commands, hooks } = await createHarness();

  await emit(hooks, sessionCreated("root"));
  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("child", "root"));
  await emit(hooks, sessionCreated("grandchild", "child"));
  await emit(hooks, sessionCreated("child", "grandchild"));
  await emit(hooks, sessionStatus("root", "idle"));

  expectCommands(commands, working);
});

test("retains idle lifecycle received before delayed session creation", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionStatus("child", "idle"));
  await emit(hooks, sessionCreated("child", "root"));
  await emit(hooks, sessionStatus("root", "idle"));

  expectCommands(commands, working, clear);
});

test("retains terminal lifecycle received before delayed session creation", async () => {
  for (const terminalEvent of ["session.error", "session.deleted"]) {
    const { commands, hooks } = await createHarness();

    await selectRoot(hooks, "root");
    await emit(hooks, lifecycleEvent(terminalEvent, "child"));
    await emit(hooks, sessionCreated("child", "root"));
    await emit(hooks, sessionStatus("root", "idle"));

    expectCommands(commands, working, clear);
  }
});

test("prioritizes descendant blockers and returns to working after resolution", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("question-child", "root"));
  await emit(hooks, sessionCreated("permission-child", "root"));
  await emit(hooks, blockerEvent("question.asked", "question-child", "q1"));
  expectCommands(commands, working, question);

  await emit(hooks, blockerEvent("permission.asked", "permission-child", "p1"));
  expectCommands(commands, working, question);

  await emit(hooks, blockerEvent("question.replied", "question-child", "q1"));
  expectCommands(commands, working, question, permission);

  await emit(hooks, lifecycleEvent("session.error", "permission-child"));
  expectCommands(commands, working, question, permission, working);
});

test("clears when the final active descendant errors or is deleted", async () => {
  for (const terminalEvent of ["session.error", "session.deleted"]) {
    const { commands, hooks } = await createHarness();

    await selectRoot(hooks, "root");
    await emit(hooks, sessionCreated("child", "root"));
    await emit(hooks, sessionStatus("root", "idle"));
    await emit(hooks, lifecycleEvent(terminalEvent, "child"));

    expectCommands(commands, working, clear);
  }
});

test("deleting a child retires its known descendant subtree and blockers", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("child", "root"));
  await emit(hooks, sessionCreated("grandchild", "child"));
  await emit(hooks, blockerEvent("question.asked", "grandchild", "q1"));
  expectCommands(commands, working, question);

  await emit(hooks, lifecycleEvent("session.deleted", "child"));
  expectCommands(commands, working, question, working);

  await emit(hooks, sessionStatus("grandchild", "busy"));
  await emit(hooks, blockerEvent("permission.asked", "grandchild", "p1"));
  expectCommands(commands, working, question, working);
});

test("ignores delayed events from descendants after they become idle", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("child", "root"));
  await emit(hooks, sessionStatus("child", "busy"));
  await emit(hooks, sessionStatus("child", "idle"));
  await emit(hooks, sessionStatus("root", "idle"));
  expectCommands(commands, working, clear);

  await emit(hooks, sessionStatus("child", "busy"));
  await emit(hooks, blockerEvent("question.asked", "child", "q1"));
  await emit(hooks, blockerEvent("permission.asked", "child", "p1"));
  expectCommands(commands, working, clear);
});

test("treats duplicate modern and deprecated root idle events as idempotent", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionStatus("root", "idle"));
  await emit(hooks, sessionStatus("root", "idle"));
  await emit(hooks, lifecycleEvent("session.idle", "root"));

  expectCommands(commands, working, clear);
});

test("keeps aggregate idle transitions idempotent across modern and deprecated events", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "root");
  await emit(hooks, sessionCreated("child", "root"));
  await emit(hooks, sessionStatus("root", "idle"));
  await emit(hooks, sessionStatus("root", "idle"));
  await emit(hooks, lifecycleEvent("session.idle", "root"));
  expectCommands(commands, working);

  await emit(hooks, sessionStatus("child", "idle"));
  await emit(hooks, sessionStatus("child", "idle"));
  await emit(hooks, lifecycleEvent("session.idle", "child"));
  expectCommands(commands, working, clear);
});

test("root error and deletion clear and suppress delayed descendant events", async () => {
  for (const terminalEvent of ["session.error", "session.deleted"]) {
    const { commands, hooks } = await createHarness();

    await selectRoot(hooks, "root");
    await emit(hooks, sessionCreated("child", "root"));
    await emit(hooks, lifecycleEvent(terminalEvent, "root"));
    expectCommands(commands, working, clear);

    await emit(hooks, sessionStatus("child", "busy"));
    await emit(hooks, blockerEvent("question.asked", "child", "q1"));
    await emit(hooks, blockerEvent("permission.asked", "child", "p1"));
    expectCommands(commands, working, clear);
  }
});

test("latest root owns the pinned window over older root lifecycle events", async () => {
  const { commands, hooks } = await createHarness();

  await selectRoot(hooks, "first-root");
  await emit(hooks, sessionCreated("first-child", "first-root"));
  await selectRoot(hooks, "latest-root");
  await emit(hooks, sessionStatus("first-root", "idle"));
  expectCommands(commands, working);

  await emit(hooks, sessionStatus("latest-root", "idle"));
  expectCommands(commands, working, clear);

  await emit(hooks, sessionStatus("first-child", "busy"));
  await emit(hooks, blockerEvent("question.asked", "first-child", "q1"));
  await emit(hooks, blockerEvent("permission.asked", "first-child", "p1"));
  expectCommands(commands, working, clear);
});

test("protects malformed and cyclic parent graphs without interrupting hooks", async () => {
  const { commands, hooks, logs } = await createHarness();

  await emit(hooks, { event: { type: "session.created", properties: {} } });
  await emit(hooks, { event: { type: "session.status", properties: {} } });
  await emit(hooks, { event: { type: "unknown" } });
  await emit(hooks, sessionCreated("cycle-a", "cycle-b"));
  await emit(hooks, sessionCreated("cycle-b", "cycle-a"));
  await selectRoot(hooks, "cycle-a");
  await emit(hooks, sessionStatus("cycle-a", "idle"));

  expectCommands(commands, working, clear);
  expect(logs).toEqual([]);
});

test("serializes overlapping effects in reducer order", async () => {
  const runner = createDeferredCommandRunner();
  const { hooks } = await createHarness(runner);

  const selecting = selectRoot(hooks, "root");
  const asking = emit(hooks, blockerEvent("question.asked", "root", "q1"));
  await runner.waitForPending();
  expectCommands(runner.commands, working);
  expect(runner.completions).toEqual([]);

  runner.resolveNext();
  await runner.waitForPending();
  expectCommands(runner.commands, working, question);
  expect(runner.completions).toEqual([working]);

  runner.resolveNext();
  await Promise.all([selecting, asking]);
  expect(runner.completions).toEqual([working, question]);
});

test("logs failed statusline commands with their reducer context", async () => {
  const { commands, hooks, logs } = await createHarness(
    createCommandRunner((command) =>
      command === working ? new Error("set failed") : undefined,
    ),
  );

  await selectRoot(hooks, "root");

  expectCommands(commands, working);
  expect(logs).toEqual([
    {
      body: {
        service: "tmux-statusline",
        level: "error",
        message: "chat.message (working): set failed",
      },
    },
  ]);
});
