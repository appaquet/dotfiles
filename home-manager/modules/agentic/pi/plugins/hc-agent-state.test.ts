import { afterEach, expect, test } from "bun:test";
import {
  default as install,
  decodeStatus,
  encodeStatus,
  isStatusReport,
} from "./hc-agent-state.ts";

// Exact OSC 7501 report fixtures, built with the encoder so the tests assert on
// the real wire bytes rather than hard-coded strings.
const WORKING = encodeStatus("working", { app: "pi" });
const DONE = encodeStatus("done", { app: "pi" });
const BLOCKED_QUESTION = encodeStatus("blocked", { app: "pi", kind: "question" });
const ERROR = encodeStatus("error", { app: "pi", message: "boom" });

const originalStdoutWrite = process.stdout.write.bind(process.stdout);
const originalHcTerminalId = process.env.HC_TERMINAL_ID;
const originalIsTTY = (process.stdout as { isTTY?: boolean | undefined }).isTTY;

afterEach(() => {
  process.stdout.write = originalStdoutWrite;
  (process.stdout as { isTTY?: boolean | undefined }).isTTY = originalIsTTY;
  if (originalHcTerminalId === undefined) {
    delete process.env.HC_TERMINAL_ID;
  } else {
    process.env.HC_TERMINAL_ID = originalHcTerminalId;
  }
});

type Handler = (event: unknown, context?: unknown) => unknown;

function createHarness() {
  const handlers = new Map<string, Handler>();
  const eventHandlers = new Map<string, Handler>();
  const pi = {
    on(event: string, handler: Handler) {
      handlers.set(event, handler);
    },
    events: {
      on(event: string, handler: Handler) {
        eventHandlers.set(event, handler);
        return () => {};
      },
    },
  };
  return { handlers, eventHandlers, pi };
}

function makeRecorder() {
  const written: string[] = [];
  const write = (chunk: unknown, ...rest: unknown[]) => {
    if (typeof chunk === "string") written.push(chunk);
    else if (chunk instanceof Uint8Array) written.push(Buffer.from(chunk).toString("utf8"));
    const callback = rest.find((arg) => typeof arg === "function");
    if (typeof callback === "function") (callback as () => void)();
    return true;
  };
  return { written, write };
}

// Open the activation gate (tui + TTY + HC_TERMINAL_ID) and install the
// extension over a recording stdout.
function openSession() {
  const { handlers, eventHandlers, pi } = createHarness();
  install(pi);
  const recorder = makeRecorder();
  process.stdout.write = recorder.write as typeof process.stdout.write;
  process.env.HC_TERMINAL_ID = "t1";
  (process.stdout as { isTTY?: boolean }).isTTY = true;
  handlers.get("session_start")?.({}, { mode: "tui", isIdle: () => true });
  return { handlers, eventHandlers, recorder };
}

function subagent(id: string) {
  return { id, type: "general-purpose", description: "sub-agent" };
}

// --- Encoding / decoding -------------------------------------------------

test("encodeStatus emits the exact bytes for every state", () => {
  expect(encodeStatus("working", { app: "pi" })).toBe(WORKING);
  expect(encodeStatus("done", { app: "pi" })).toBe(DONE);
  expect(encodeStatus("blocked", { app: "pi", kind: "question" })).toBe(BLOCKED_QUESTION);
  expect(encodeStatus("error", { app: "pi", message: "boom" })).toBe(ERROR);
  expect(encodeStatus("error", { app: "pi", message: "boom" })).toBe(
    `\u001b]7501;state=error:app=pi:msg=${Buffer.from("boom", "utf8").toString("base64")}\u001b\\`,
  );
  // kind is only attached to a blocked report.
  expect(encodeStatus("working", { app: "pi", kind: "ignored" })).toBe(WORKING);
  // app is omitted when not supplied.
  expect(encodeStatus("idle")).toBe("\u001b]7501;state=idle\u001b\\");
});

test("decodeStatus round-trips a Pi report and rejects non-reports", () => {
  expect(decodeStatus(DONE)).toEqual({ state: "done", app: "pi" });
  expect(decodeStatus(ERROR)).toEqual({ state: "error", app: "pi", message: "boom" });
  expect(decodeStatus(BLOCKED_QUESTION)).toEqual({
    state: "blocked",
    app: "pi",
    kind: "question",
  });
  expect(decodeStatus("plain text")).toBeNull();
  // A report embedded in a larger frame is not "exactly one report".
  expect(decodeStatus(`prefix${DONE}`)).toBeNull();
  expect(decodeStatus(`${DONE}\u001b[2J`)).toBeNull();
});

test("isStatusReport matches only a single complete report", () => {
  expect(isStatusReport(WORKING)).toBe(true);
  expect(isStatusReport(ERROR)).toBe(true);
  expect(isStatusReport("\u001b[2Jframe")).toBe(false);
  expect(isStatusReport(`${DONE}\u001b[2J`)).toBe(false);
  expect(isStatusReport(Buffer.from(WORKING))).toBe(true);
});

// --- Activation gate -----------------------------------------------------


function createHarnessAndWrite() {
  const { handlers, eventHandlers, pi } = createHarness();
  install(pi);
  const recorder = makeRecorder();
  process.stdout.write = recorder.write as typeof process.stdout.write;
  return { handlers, eventHandlers, recorder };
}

test("strict pass-through when mode is not tui", () => {
  const { handlers, eventHandlers, recorder } = createHarnessAndWrite();
  process.env.HC_TERMINAL_ID = "t1";
  (process.stdout as { isTTY?: boolean }).isTTY = true;
  handlers.get("session_start")?.({}, { mode: "rpc", isIdle: () => true });

  // A sub-agent starting and a Pi report must not be rewritten.
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  process.stdout.write(DONE);
  expect(recorder.written).toEqual([DONE]);
});

test("strict pass-through when HC_TERMINAL_ID is missing", () => {
  const { handlers, eventHandlers, recorder } = createHarnessAndWrite();
  delete process.env.HC_TERMINAL_ID;
  (process.stdout as { isTTY?: boolean }).isTTY = true;
  handlers.get("session_start")?.({}, { mode: "tui", isIdle: () => true });

  eventHandlers.get("subagents:started")?.(subagent("a1"));
  process.stdout.write(DONE);
  expect(recorder.written).toEqual([DONE]);
});

test("with the gate open, nothing rewrites before Pi's first report", () => {
  const { handlers, eventHandlers, recorder } = openSession();

  // A sub-agent starts before Pi has reported: the override is tracked but not
  // emitted (piReported is still false).
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  expect(recorder.written).toEqual([]);

  // A TUI frame passes through untouched.
  process.stdout.write("\u001b[2Jframe");
  expect(recorder.written).toEqual(["\u001b[2Jframe"]);
});

test("a terminal that never answers the query sees no rewrite at all", () => {
  const { eventHandlers, recorder } = openSession();
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  eventHandlers.get("herdr:blocked")?.({ active: true });
  expect(recorder.written).toEqual([]);
});

// --- Sub-agent transitions (R2) -----------------------------------------

test("sub-agent started reports working even when Pi's cached record is done", () => {
  const { eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);
  expect(recorder.written).toEqual([DONE]);

  eventHandlers.get("subagents:started")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING]);

  // The last agent finishing restores Pi's cached done.
  eventHandlers.get("subagents:completed")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING, DONE]);
});

test("a failed sub-agent counts as terminal", () => {
  const { eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  eventHandlers.get("subagents:failed")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING, DONE]);
});

test("the terminal stays working until every concurrent sub-agent ends", () => {
  const { eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);
  eventHandlers.get("subagents:created")?.(subagent("a1"));
  eventHandlers.get("subagents:started")?.(subagent("a2"));
  expect(recorder.written).toEqual([DONE, WORKING]);

  eventHandlers.get("subagents:completed")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING]);

  eventHandlers.get("subagents:completed")?.(subagent("a2"));
  expect(recorder.written).toEqual([DONE, WORKING, DONE]);
});

// --- Questionnaire transitions (R3) -------------------------------------

test("an open questionnaire reports blocked with kind=question, outranking working", () => {
  const { eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING]);

  eventHandlers.get("herdr:blocked")?.({ active: true });
  expect(recorder.written).toEqual([DONE, WORKING, BLOCKED_QUESTION]);

  // Closing the questionnaire returns to the sub-agent's working.
  eventHandlers.get("herdr:blocked")?.({ active: false });
  expect(recorder.written).toEqual([DONE, WORKING, BLOCKED_QUESTION, WORKING]);
});

test("concurrent questionnaires keep blocked until the last closes", () => {
  const { eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);

  eventHandlers.get("herdr:blocked")?.({ active: true });
  eventHandlers.get("herdr:blocked")?.({ active: true });
  // Only the first active produced a write; the second is deduped.
  expect(recorder.written).toEqual([DONE, BLOCKED_QUESTION]);

  eventHandlers.get("herdr:blocked")?.({ active: false });
  expect(recorder.written).toEqual([DONE, BLOCKED_QUESTION]);

  eventHandlers.get("herdr:blocked")?.({ active: false });
  expect(recorder.written).toEqual([DONE, BLOCKED_QUESTION, DONE]);
});

// --- Caching Pi's report under an active override (R4) -------------------

test("a Pi report during an active override is cached, and the newest is restored on clear", () => {
  const { eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING]);

  // Pi reports an error while the sub-agent runs: cached, not written.
  process.stdout.write(ERROR);
  expect(recorder.written).toEqual([DONE, WORKING]);

  // The last sub-agent finishing restores the newest cached record (the error).
  eventHandlers.get("subagents:completed")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING, ERROR]);
});

test("non-status bytes pass through unchanged under an active override", () => {
  const { eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  process.stdout.write("\u001b[2Jframe");
  expect(recorder.written).toEqual([DONE, WORKING, "\u001b[2Jframe"]);
});

// --- Shutdown (R4) -------------------------------------------------------

test("session_shutdown restores the original write and stops substituting", () => {
  const { handlers, eventHandlers, recorder } = openSession();
  process.stdout.write(DONE);
  eventHandlers.get("subagents:started")?.(subagent("a1"));
  expect(recorder.written).toEqual([DONE, WORKING]);

  handlers.get("session_shutdown")?.({}, { mode: "tui" });

  // A report and a sub-agent event after shutdown pass through / are ignored.
  eventHandlers.get("subagents:completed")?.(subagent("a1"));
  process.stdout.write(DONE);
  expect(recorder.written).toEqual([DONE, WORKING, DONE]);
});
