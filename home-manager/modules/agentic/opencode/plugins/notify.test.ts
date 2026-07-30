import { expect, test } from "bun:test";

import { NotifyPlugin } from "./notify";

type ShellCommand = {
  quiet: () => ShellCommand;
  catch: (handler: () => void) => Promise<void>;
};

type Hooks = {
  event: (context: unknown) => Promise<void>;
};

async function createHarness(): Promise<{
  commands: string[];
  hooks: Hooks;
}> {
  const commands: string[] = [];
  const tag = (strings: TemplateStringsArray, ...values: unknown[]) => {
    const command = strings.reduce(
      (result, string, index) =>
        `${result}${string}${index < values.length ? String(values[index]) : ""}`,
      "",
    );
    commands.push(command);

    const shellCommand: ShellCommand = {
      quiet: () => shellCommand,
      catch: async () => {},
    };
    return shellCommand;
  };

  const hooks = (await NotifyPlugin({ $: tag } as never)) as unknown as Hooks;
  return { commands, hooks };
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
          title: "Root task",
          ...(parentID ? { parentID } : {}),
        },
      },
    },
  };
}

function sessionStatus(
  sessionID: string,
  status: "busy" | "idle",
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

test("waits for active child sessions before notifying completion", async () => {
  const { commands, hooks } = await createHarness();

  await emit(hooks, sessionCreated("root"));
  await emit(hooks, sessionCreated("child", "root"));
  await emit(hooks, sessionStatus("child", "busy"));
  await emit(hooks, sessionStatus("root", "idle"));

  expect(commands).toEqual([]);

  await emit(hooks, sessionStatus("child", "idle"));

  expect(commands).toEqual(['notify "task complete" "Opencode - Root task"']);
});

test("does not notify twice for duplicate idle events", async () => {
  const { commands, hooks } = await createHarness();

  await emit(hooks, sessionCreated("root"));
  await emit(hooks, sessionStatus("root", "idle"));
  await emit(hooks, {
    event: {
      type: "session.idle",
      properties: { sessionID: "root" },
    },
  });

  expect(commands).toEqual(['notify "task complete" "Opencode - Root task"']);
});
