import { afterEach, expect, test } from "bun:test";
import { rm } from "node:fs/promises";
import net, { createServer, type Server } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";

const originalPlatform = process.platform;
const originalCreateConnection = net.createConnection;
const originalEnvironment = {
  HERDR_ENV: process.env.HERDR_ENV,
  HERDR_OMP_IDLE_DEBOUNCE_MS: process.env.HERDR_OMP_IDLE_DEBOUNCE_MS,
  HERDR_PANE_ID: process.env.HERDR_PANE_ID,
  HERDR_SOCKET_PATH: process.env.HERDR_SOCKET_PATH,
};

let server: Server | undefined;
let socketPath: string | undefined;
let importCounter = 0;

afterEach(async () => {
  await new Promise<void>((resolve, reject) => {
    if (!server) {
      resolve();
      return;
    }
    server.close((error) => (error ? reject(error) : resolve()));
  });
  server = undefined;

  if (socketPath) {
    await rm(socketPath, { force: true });
    socketPath = undefined;
  }

  Object.defineProperty(process, "platform", { value: originalPlatform });
  net.createConnection = originalCreateConnection;
  for (const [name, value] of Object.entries(originalEnvironment)) {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }
});

function importFresh(modulePath: string) {
  importCounter += 1;
  return import(`${modulePath}?test=${importCounter}`);
}

type Handler = (event: unknown, context: unknown) => unknown;

function createExtensionHarness() {
  const handlers = new Map<string, Handler>();
  const eventHandlers = new Map<string, Handler>();
  return {
    handlers,
    eventHandlers,
    pi: {
      on(event: string, handler: Handler) {
        handlers.set(event, handler);
      },
      events: {
        on(event: string, handler: Handler) {
          eventHandlers.set(event, handler);
          return () => {};
        },
      },
    },
  };
}

function configureIntegrationEnvironment(recordingSocketPath: string) {
  process.env.HERDR_ENV = "1";
  process.env.HERDR_SOCKET_PATH = recordingSocketPath;
  process.env.HERDR_PANE_ID = "test:p1";
}

function captureConnectionEndpoint() {
  let connectedEndpoint: unknown;
  net.createConnection = ((...args: unknown[]) => {
    connectedEndpoint = args[0];
    return Reflect.apply(originalCreateConnection, net, args);
  }) as typeof net.createConnection;
  return () => connectedEndpoint;
}

async function startRecordingServer(name: string): Promise<unknown[]> {
  const recordingSocketPath = join(tmpdir(), `herdr-${name}-${process.pid}.sock`);
  socketPath = recordingSocketPath;
  await rm(recordingSocketPath, { force: true });

  const requests: unknown[] = [];
  const recordingServer = createServer((socket) => {
    let input = "";
    socket.setEncoding("utf8");
    socket.on("data", (chunk) => {
      input += chunk;
      const newline = input.indexOf("\n");
      if (newline === -1) {
        return;
      }
      requests.push(JSON.parse(input.slice(0, newline)));
      socket.end("{}\n");
    });
  });
  server = recordingServer;
  await new Promise<void>((resolve, reject) => {
    recordingServer.once("error", reject);
    recordingServer.listen(recordingSocketPath, resolve);
  });
  configureIntegrationEnvironment(recordingSocketPath);
  return requests;
}

test("Pi maps the Windows socket marker path to a named pipe endpoint", async () => {
  const markerPath = `herdr-pi-${process.pid}.sock`;
  configureIntegrationEnvironment(markerPath);
  Object.defineProperty(process, "platform", { value: "win32" });
  const connectedEndpoint = captureConnectionEndpoint();
  const { handlers, pi } = createExtensionHarness();

  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);
  await handlers.get("session_start")?.(
    { reason: "startup" },
    {
      hasUI: true,
      mode: "tui",
      isIdle: () => true,
      sessionManager: {
        getSessionFile: () => undefined,
        getSessionId: () => "test-session",
      },
    },
  );

  expect(connectedEndpoint()).toBe(`\\\\.\\pipe\\${markerPath}`);
});

test("Pi reload preserves working state when the agent is active", async () => {
  const requests = await startRecordingServer("pi");
  const { handlers, pi } = createExtensionHarness();

  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const sessionStart = handlers.get("session_start");
  expect(sessionStart).toBeDefined();
  await sessionStart?.(
    { reason: "reload" },
    {
      hasUI: true,
      mode: "tui",
      isIdle: () => false,
      sessionManager: {
        getSessionFile: () => undefined,
        getSessionId: () => undefined,
      },
    },
  );

  const reportedState = () => {
    for (const request of requests) {
      if (!isRecord(request) || request.method !== "pane.report_agent") {
        continue;
      }
      const params = request.params;
      if (isRecord(params) && typeof params.state === "string") {
        return params.state;
      }
    }
    return undefined;
  };

  const deadline = Date.now() + 1_000;
  while (Date.now() < deadline && reportedState() === undefined) {
    await Bun.sleep(5);
  }

  expect(reportedState()).toBe("working");
});

test("Pi reports idle only after the agent settles", async () => {
  const requests = await startRecordingServer("pi-settled");
  const { handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  expect(completionHandlers(handlers)).toEqual(["agent_settled"]);
  let idle = true;
  const context = piContext(() => idle);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  idle = false;
  handlers.get("agent_start")?.({}, context);
  await waitFor(() => requestStates(requests).length === 2);
  expect(requestStates(requests)).toEqual(["idle", "working"]);
  expect(handlers.has("agent_end")).toBe(false);

  const requestCountBeforeStaleSettlement = requests.length;
  handlers.get("agent_settled")?.({}, context);
  await Bun.sleep(25);
  expect(requests).toHaveLength(requestCountBeforeStaleSettlement);
  expect(requestStates(requests)).toEqual(["idle", "working"]);

  idle = true;
  handlers.get("agent_settled")?.({}, context);
  await waitFor(() => requestStates(requests).length === 3);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);
});

test("Pi ignores RPC sessions even when UI APIs are available", async () => {
  const requests = await startRecordingServer("pi-rpc");
  const { handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const context = {
    ...piContext(() => true),
    hasUI: true,
    mode: "rpc",
  };
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  handlers.get("agent_start")?.({}, context);
  handlers.get("agent_settled")?.({}, context);
  await Bun.sleep(25);

  expect(requests).toEqual([]);
});

test("Pi settlement preserves explicit blocked-state precedence", async () => {
  const requests = await startRecordingServer("pi-settled-blocked");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  let idle = true;
  const context = piContext(() => idle);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);
  idle = false;
  handlers.get("agent_start")?.({}, context);
  await waitFor(() => requestStates(requests).length === 2);
  eventHandlers.get("herdr:blocked")?.({ active: true, label: "approval" }, context);
  await waitFor(() => requestStates(requests).length === 3);

  idle = true;
  handlers.get("agent_settled")?.({}, context);
  await Bun.sleep(25);
  expect(requestStates(requests)).toEqual(["idle", "working", "blocked"]);

  eventHandlers.get("herdr:blocked")?.({ active: false }, context);
  await waitFor(() => requestStates(requests).length === 4);
  expect(requestStates(requests)).toEqual(["idle", "working", "blocked", "idle"]);
});

test("Pi keeps a queued sub-agent working after the root settles", async () => {
  const requests = await startRecordingServer("pi-subagent-queued");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  let idle = true;
  const context = piContext(() => idle);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  idle = false;
  handlers.get("agent_start")?.({}, context);
  await waitFor(() => requestStates(requests).length === 2);

  eventHandlers.get("subagents:created")?.(subagentEvent("queued-agent"), context);
  idle = true;
  handlers.get("agent_settled")?.({}, context);
  await Bun.sleep(25);

  expect(requestStates(requests)).toEqual(["idle", "working"]);

  eventHandlers.get("subagents:completed")?.(subagentEvent("queued-agent"), context);
  await waitFor(() => requestStates(requests).length === 3);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);
});

test("Pi starts scheduled sub-agents without counting future schedules", async () => {
  const requests = await startRecordingServer("pi-subagent-scheduled");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const context = piContext(() => true);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  eventHandlers.get("subagents:scheduled")?.(subagentEvent("future-agent"), context);
  await Bun.sleep(25);
  expect(requestStates(requests)).toEqual(["idle"]);

  eventHandlers.get("subagents:started")?.(subagentEvent("scheduled-agent"), context);
  await waitFor(() => requestStates(requests).length === 2);
  expect(requestStates(requests)).toEqual(["idle", "working"]);

  eventHandlers.get("subagents:completed")?.(subagentEvent("scheduled-agent"), context);
  await waitFor(() => requestStates(requests).length === 3);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);
});

test("Pi waits for every concurrent sub-agent to terminate", async () => {
  const requests = await startRecordingServer("pi-subagent-concurrent");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const context = piContext(() => true);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  eventHandlers.get("subagents:created")?.(subagentEvent("first-agent"), context);
  eventHandlers.get("subagents:started")?.(subagentEvent("second-agent"), context);
  await waitFor(() => requestStates(requests).length === 2);
  expect(requestStates(requests)).toEqual(["idle", "working"]);

  eventHandlers.get("subagents:completed")?.(subagentEvent("first-agent"), context);
  await Bun.sleep(25);
  expect(requestStates(requests)).toEqual(["idle", "working"]);

  eventHandlers.get("subagents:completed")?.(subagentEvent("second-agent"), context);
  await waitFor(() => requestStates(requests).length === 3);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);
});

for (const failedFixture of [
  { id: "error-agent", status: "error", error: "timed out" },
  { id: "stopped-agent", status: "stopped" },
  { id: "aborted-agent", status: "aborted" },
]) {
  test(`Pi returns idle when the final sub-agent ${failedFixture.status}`, async () => {
    const requests = await startRecordingServer(`pi-subagent-${failedFixture.status}`);
    const { eventHandlers, handlers, pi } = createExtensionHarness();
    const { default: install } = await importFresh("./herdr-agent-state.ts");
    install(pi);

    const context = piContext(() => true);
    await handlers.get("session_start")?.({ reason: "startup" }, context);
    await waitFor(() => requestStates(requests).length === 1);

    eventHandlers.get("subagents:created")?.(subagentEvent(failedFixture.id), context);
    await waitFor(() => requestStates(requests).length === 2);

    eventHandlers.get("subagents:failed")?.(subagentEvent(failedFixture.id, failedFixture), context);
    await waitFor(() => requestStates(requests).length === 3);
    expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);
  });
}

test("Pi de-duplicates sub-agent lifecycle events", async () => {
  const requests = await startRecordingServer("pi-subagent-duplicates");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const context = piContext(() => true);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  eventHandlers.get("subagents:created")?.(subagentEvent("duplicate-agent"), context);
  eventHandlers.get("subagents:created")?.(subagentEvent("duplicate-agent"), context);
  eventHandlers.get("subagents:started")?.(subagentEvent("duplicate-agent"), context);
  await waitFor(() => requestStates(requests).length === 2);
  expect(requestStates(requests)).toEqual(["idle", "working"]);

  eventHandlers.get("subagents:completed")?.(subagentEvent("duplicate-agent"), context);
  eventHandlers.get("subagents:failed")?.(
    subagentEvent("duplicate-agent", { status: "error", error: "late duplicate" }),
    context,
  );
  await waitFor(() => requestStates(requests).length === 3);
  await Bun.sleep(25);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);
});

test("Pi ignores stale creation after a terminal sub-agent event", async () => {
  const requests = await startRecordingServer("pi-subagent-stale-created");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const context = piContext(() => true);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  eventHandlers.get("subagents:started")?.(subagentEvent("reused-agent"), context);
  await waitFor(() => requestStates(requests).length === 2);
  eventHandlers.get("subagents:failed")?.(
    subagentEvent("reused-agent", { status: "error", error: "failed run" }),
    context,
  );
  await waitFor(() => requestStates(requests).length === 3);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);

  eventHandlers.get("subagents:created")?.(subagentEvent("reused-agent"), context);
  await Bun.sleep(25);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);

  eventHandlers.get("subagents:started")?.(subagentEvent("reused-agent"), context);
  await waitFor(() => requestStates(requests).length === 4);
  eventHandlers.get("subagents:completed")?.(subagentEvent("reused-agent"), context);
  await waitFor(() => requestStates(requests).length === 5);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle", "working", "idle"]);
});

test("Pi ignores malformed sub-agent IDs", async () => {
  const requests = await startRecordingServer("pi-subagent-malformed");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const context = piContext(() => true);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  for (const malformedEvent of [undefined, {}, { id: "" }, { id: 42 }]) {
    eventHandlers.get("subagents:created")?.(malformedEvent, context);
    eventHandlers.get("subagents:started")?.(malformedEvent, context);
  }
  await Bun.sleep(25);
  expect(requestStates(requests)).toEqual(["idle"]);

  eventHandlers.get("subagents:started")?.(subagentEvent("valid-agent"), context);
  await waitFor(() => requestStates(requests).length === 2);

  for (const malformedEvent of [undefined, {}, { id: "" }, { id: 42 }]) {
    eventHandlers.get("subagents:completed")?.(malformedEvent, context);
    eventHandlers.get("subagents:failed")?.(malformedEvent, context);
  }
  await Bun.sleep(25);
  expect(requestStates(requests)).toEqual(["idle", "working"]);

  eventHandlers.get("subagents:completed")?.(subagentEvent("valid-agent"), context);
  await waitFor(() => requestStates(requests).length === 3);
  expect(requestStates(requests)).toEqual(["idle", "working", "idle"]);
});

test("Pi restores aggregate sub-agent work after blocked state clears", async () => {
  const requests = await startRecordingServer("pi-subagent-blocked");
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const context = piContext(() => true);
  await handlers.get("session_start")?.({ reason: "startup" }, context);
  await waitFor(() => requestStates(requests).length === 1);

  eventHandlers.get("subagents:created")?.(subagentEvent("blocked-agent"), context);
  await waitFor(() => requestStates(requests).length === 2);
  eventHandlers.get("herdr:blocked")?.({ active: true, label: "approval" }, context);
  await waitFor(() => requestStates(requests).length === 3);
  eventHandlers.get("herdr:blocked")?.({ active: false }, context);
  await waitFor(() => requestStates(requests).length === 4);
  expect(requestStates(requests)).toEqual(["idle", "working", "blocked", "working"]);

  eventHandlers.get("subagents:completed")?.(subagentEvent("blocked-agent"), context);
  await waitFor(() => requestStates(requests).length === 5);
  expect(requestStates(requests)).toEqual(["idle", "working", "blocked", "working", "idle"]);
});

test("Pi reports the session replacement source", async () => {
  const requests = await startRecordingServer("pi-session-source");
  const { handlers, pi } = createExtensionHarness();

  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const sessionStart = handlers.get("session_start");
  expect(sessionStart).toBeDefined();
  await sessionStart?.(
    { reason: "new" },
    {
      hasUI: true,
      mode: "tui",
      isIdle: () => true,
      sessionManager: {
        getSessionFile: () => "/tmp/pi-new.jsonl",
        getSessionId: () => "pi-new",
      },
    },
  );

  const reportedSession = () =>
    requests.find((request) => isRecord(request) && request.method === "pane.report_agent_session");
  const deadline = Date.now() + 1_000;
  while (Date.now() < deadline && reportedSession() === undefined) {
    await Bun.sleep(5);
  }

  const request = reportedSession();
  expect(request).toBeDefined();
  expect(isRecord(request) && isRecord(request.params) ? request.params.session_start_source : null)
    .toBe("new");
});

test("Pi waits for a replacement session report before publishing state", async () => {
  const recordingSocketPath = join(tmpdir(), `herdr-pi-session-order-${process.pid}.sock`);
  socketPath = recordingSocketPath;
  await rm(recordingSocketPath, { force: true });

  const requests: unknown[] = [];
  let acknowledgeSessionReport: (() => void) | undefined;
  const recordingServer = createServer((socket) => {
    let input = "";
    socket.setEncoding("utf8");
    socket.on("data", (chunk) => {
      input += chunk;
      const newline = input.indexOf("\n");
      if (newline === -1) {
        return;
      }
      const request = JSON.parse(input.slice(0, newline));
      requests.push(request);
      if (isRecord(request) && request.method === "pane.report_agent_session") {
        acknowledgeSessionReport = () => socket.end("{}\n");
        return;
      }
      socket.end("{}\n");
    });
  });
  server = recordingServer;
  await new Promise<void>((resolve, reject) => {
    recordingServer.once("error", reject);
    recordingServer.listen(recordingSocketPath, resolve);
  });

  configureIntegrationEnvironment(recordingSocketPath);
  const { handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const sessionStart = handlers.get("session_start");
  expect(sessionStart).toBeDefined();
  const sessionStartResult = sessionStart?.(
    { reason: "new" },
    {
      hasUI: true,
      mode: "tui",
      isIdle: () => false,
      sessionManager: {
        getSessionFile: () => "/tmp/pi-new.jsonl",
        getSessionId: () => "pi-new",
      },
    },
  );

  const deadline = Date.now() + 1_000;
  while (Date.now() < deadline && acknowledgeSessionReport === undefined) {
    await Bun.sleep(5);
  }
  expect(acknowledgeSessionReport).toBeDefined();
  expect(
    requests.some((request) => isRecord(request) && request.method === "pane.report_agent"),
  ).toBe(false);

  acknowledgeSessionReport?.();
  await sessionStartResult;

  const stateDeadline = Date.now() + 1_000;
  while (
    Date.now() < stateDeadline &&
    !requests.some((request) => isRecord(request) && request.method === "pane.report_agent")
  ) {
    await Bun.sleep(5);
  }
  expect(requests.map((request) => (isRecord(request) ? request.method : undefined))).toEqual([
    "pane.report_agent_session",
    "pane.report_agent",
  ]);
});

test("Pi queues sub-agent state until session identity is acknowledged", async () => {
  const recordingSocketPath = join(tmpdir(), `herdr-pi-session-subagent-order-${process.pid}.sock`);
  socketPath = recordingSocketPath;
  await rm(recordingSocketPath, { force: true });

  const requests: unknown[] = [];
  let acknowledgeSessionReport: (() => void) | undefined;
  const recordingServer = createServer((socket) => {
    let input = "";
    socket.setEncoding("utf8");
    socket.on("data", (chunk) => {
      input += chunk;
      const newline = input.indexOf("\n");
      if (newline === -1) {
        return;
      }
      const request = JSON.parse(input.slice(0, newline));
      requests.push(request);
      if (isRecord(request) && request.method === "pane.report_agent_session") {
        acknowledgeSessionReport = () => socket.end("{}\n");
        return;
      }
      socket.end("{}\n");
    });
  });
  server = recordingServer;
  await new Promise<void>((resolve, reject) => {
    recordingServer.once("error", reject);
    recordingServer.listen(recordingSocketPath, resolve);
  });

  configureIntegrationEnvironment(recordingSocketPath);
  const { eventHandlers, handlers, pi } = createExtensionHarness();
  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const sessionStart = handlers.get("session_start");
  expect(sessionStart).toBeDefined();
  const sessionStartResult = sessionStart?.(
    { reason: "new" },
    {
      hasUI: true,
      mode: "tui",
      isIdle: () => true,
      sessionManager: {
        getSessionFile: () => "/tmp/pi-new.jsonl",
        getSessionId: () => "pi-new",
      },
    },
  );

  await waitFor(() => acknowledgeSessionReport !== undefined);
  eventHandlers.get("subagents:started")?.(subagentEvent("scheduled-agent"), undefined);
  await Bun.sleep(25);
  expect(requests.map((request) => (isRecord(request) ? request.method : undefined))).toEqual([
    "pane.report_agent_session",
  ]);

  acknowledgeSessionReport?.();
  await sessionStartResult;
  await waitFor(() => requests.length === 2);
  expect(requests.map((request) => (isRecord(request) ? request.method : undefined))).toEqual([
    "pane.report_agent_session",
    "pane.report_agent",
  ]);
  expect(requestStates(requests)).toEqual(["working"]);
});

async function startDroppedFirstResponseServer(name: string) {
  const recordingSocketPath = join(tmpdir(), `herdr-${name}-${process.pid}.sock`);
  socketPath = recordingSocketPath;
  await rm(recordingSocketPath, { force: true });

  let connectionCount = 0;
  const attemptedRequests: unknown[] = [];
  const deliveredRequests: unknown[] = [];
  const recordingServer = createServer((socket) => {
    connectionCount += 1;
    const connectionNumber = connectionCount;
    let input = "";
    socket.setEncoding("utf8");
    socket.on("data", (chunk) => {
      input += chunk;
      const newline = input.indexOf("\n");
      if (newline === -1) {
        return;
      }
      const request = JSON.parse(input.slice(0, newline));
      attemptedRequests.push(request);
      if (connectionNumber === 1) {
        return;
      }
      deliveredRequests.push(request);
      socket.end("{}\n");
    });
  });
  server = recordingServer;
  await new Promise<void>((resolve, reject) => {
    recordingServer.once("error", reject);
    recordingServer.listen(recordingSocketPath, resolve);
  });

  configureIntegrationEnvironment(recordingSocketPath);
  return {
    attemptedRequests,
    deliveredRequests,
    connectionCount: () => connectionCount,
  };
}

test("Pi retries working state after an unanswered socket attempt", async () => {
  const { attemptedRequests, deliveredRequests, connectionCount } =
    await startDroppedFirstResponseServer("pi-retry");
  const { handlers, pi } = createExtensionHarness();

  const { default: install } = await importFresh("./herdr-agent-state.ts");
  install(pi);

  const sessionStart = handlers.get("session_start");
  expect(sessionStart).toBeDefined();
  await sessionStart?.(
    { reason: "startup" },
    {
      hasUI: true,
      mode: "tui",
      isIdle: () => false,
      sessionManager: {
        getSessionFile: () => undefined,
        getSessionId: () => undefined,
      },
    },
  );

  const reportedWorking = () =>
    deliveredRequests.some((request) => {
      if (!isRecord(request) || request.method !== "pane.report_agent") {
        return false;
      }
      const params = request.params;
      return isRecord(params) && params.state === "working";
    });

  const deadline = Date.now() + 2_500;
  while (Date.now() < deadline && !reportedWorking()) {
    await Bun.sleep(5);
  }

  expect(connectionCount()).toBeGreaterThanOrEqual(2);
  expect(attemptedRequests.length).toBeGreaterThanOrEqual(2);
  expect(attemptedRequests[1]).toEqual(attemptedRequests[0]);
  expect(reportedWorking()).toBe(true);
});

function subagentEvent(id: string, fields: Record<string, unknown> = {}) {
  return {
    id,
    type: "general-purpose",
    description: "Test sub-agent",
    ...fields,
  };
}

function completionHandlers(handlers: Map<string, Handler>): string[] {
  return ["agent_end", "agent_settled"].filter((event) => handlers.has(event));
}

function piContext(isIdle: () => boolean) {
  return {
    hasUI: true,
    mode: "tui",
    isIdle,
    sessionManager: {
      getSessionFile: () => undefined,
      getSessionId: () => undefined,
    },
  };
}

function requestStates(requests: unknown[]): unknown[] {
  return requests
    .filter((request) => isRecord(request) && request.method === "pane.report_agent")
    .map(requestState);
}

async function waitFor(predicate: () => boolean, timeoutMs = 1_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline && !predicate()) {
    await Bun.sleep(5);
  }
  expect(predicate()).toBe(true);
}

function requestState(request: unknown): unknown {
  if (!isRecord(request) || !isRecord(request.params)) {
    return undefined;
  }
  return request.params.state;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

