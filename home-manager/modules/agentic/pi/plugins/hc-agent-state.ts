// Pi integration for herdr-core agent status.
//
// herdr-core reads a terminal's agent status only from the Program Status
// Protocol (OSC 7501) the program writes to its own stdout. Pi already writes
// that (pi-tui's reporter), but the reporter tracks only the root turn: an
// in-process sub-agent (pi-subagents) keeps working after the root settles, and
// an ask_user_question questionnaire never reports blocked. This extension
// rewrites Pi's own status reports while either of those is outstanding, and
// passes everything else through unchanged. The transport is terminal bytes,
// and the process-global stdout wrapper should exist only where it is needed.

const ESC = "\x1b";

// A complete OSC 7501 status report: ESC ]7501; then key=value pairs joined by
// ":", terminated by ESC \, with no other escape inside. This is exactly what
// pi-tui writes for a single report (see its formatProgramStatus).
const STATUS_REPORT_RE = new RegExp(`^${ESC}\\]7501;([^${ESC}]*)${ESC}\\\\$`);

// `app` value characters, mirroring pi-tui's APP_PATTERN.
const APP_RE = /^[A-Za-z0-9_.+-]{1,32}$/;

type StatusRecord = {
  state: string;
  app?: string;
  kind?: string;
  message?: string;
};

type SubagentLifecycle = "live" | "terminal";

export default function registerHcAgentState(pi: any): void {
  // All mutable state lives in this closure so each install is independent.
  let rootSession = false;
  let gateOpen = false;
  let piReported = false;
  let lastPiChunk: string | null = null;
  let lastEmitted: string | null = null;
  let originalWrite: ((...args: unknown[]) => boolean) | undefined;
  const activeSubagentIds = new Set<string>();
  let blockedCount = 0;

  // The override the terminal should show on top of Pi's own report. A pending
  // questionnaire outranks sub-agent work; otherwise a live sub-agent forces
  // working. Nothing means "show exactly what Pi reported".
  function activeOverride(): StatusRecord | null {
    if (blockedCount > 0) {
      return { state: "blocked", kind: "question" };
    }
    if (activeSubagentIds.size > 0) {
      return { state: "working" };
    }
    return null;
  }

  // Emit the effective record, skipping a repeat of the last bytes written so a
  // held "working" does not re-report on every Pi frame. herdr-core stores the
  // latest record, so writing only on change keeps its turn counter stable.
  function flush(): void {
    if (!gateOpen || !piReported) {
      return;
    }
    const override = activeOverride();
    const output = override
      ? encodeStatus(override.state, { app: "pi", kind: override.kind })
      : lastPiChunk;
    if (output === null || output === lastEmitted) {
      return;
    }
    lastEmitted = output;
    originalWrite?.(output);
  }

  // The installed stdout writer. A chunk that is exactly one status report is
  // decoded and cached; when an override is active the override is written
  // instead (the Pi report is cached for later restore). Every other byte and
  // every non-report chunk (TUI frames, coalesced output) passes through.
  function wrapperWrite(chunk: unknown, ...rest: unknown[]): boolean {
    const text = toUtf8String(chunk);
    if (text !== undefined && isStatusReport(text)) {
      lastPiChunk = text;
      piReported = true;
      flush();
      const callback = rest.find((arg) => typeof arg === "function");
      if (typeof callback === "function") {
        (callback as () => void)();
      }
      return true;
    }
    return originalWrite ? originalWrite(chunk, ...rest) : true;
  }

  function installWrapper(): void {
    if (originalWrite) {
      return;
    }
    originalWrite = process.stdout.write.bind(process.stdout);
    process.stdout.write = (chunk: unknown, ...rest: unknown[]) =>
      wrapperWrite(chunk, ...rest);
  }

  function restoreWrapper(): void {
    if (originalWrite) {
      process.stdout.write = originalWrite;
      originalWrite = undefined;
    }
  }

  function updateSubagentActivity(event: unknown, lifecycle: SubagentLifecycle): void {
    if (!gateOpen || typeof event !== "object" || event === null) {
      return;
    }
    const id = (event as { id?: unknown }).id;
    if (typeof id !== "string" || id.length === 0) {
      return;
    }
    if (lifecycle === "terminal") {
      activeSubagentIds.delete(id);
    } else {
      activeSubagentIds.add(id);
    }
    flush();
  }

  pi.on("session_start", (_event: unknown, ctx: any) => {
    // TUI only: print/JSON/RPC modes are headless and must emit no status bytes.
    if (ctx?.mode !== "tui") {
      return;
    }
    // A real TTY in a herdr-core terminal. HC_TERMINAL_ID is the cheap early-out
    // that keeps this herdr-core-specific work out of every other terminal.
    if (!process.stdout.isTTY || !process.env.HC_TERMINAL_ID) {
      return;
    }
    rootSession = true;
    gateOpen = true;
    piReported = false;
    lastPiChunk = null;
    lastEmitted = null;
    installWrapper();
  });

  pi.on("session_shutdown", () => {
    if (gateOpen) {
      restoreWrapper();
    }
    gateOpen = false;
    rootSession = false;
    piReported = false;
    lastPiChunk = null;
    lastEmitted = null;
    activeSubagentIds.clear();
    blockedCount = 0;
  });

  for (const lifecycle of ["subagents:created", "subagents:started"] as const) {
    pi.events.on(lifecycle, (event: unknown) => updateSubagentActivity(event, "live"));
  }
  for (const lifecycle of ["subagents:completed", "subagents:failed"] as const) {
    pi.events.on(lifecycle, (event: unknown) => updateSubagentActivity(event, "terminal"));
  }

  pi.events.on("rpiv:ask-user:blocked", (data: unknown) => {
    if (!rootSession || !isBlockedEvent(data)) {
      return;
    }
    if (!data.active) {
      blockedCount = Math.max(0, blockedCount - 1);
    } else {
      blockedCount += 1;
    }
    flush();
  });
}

// Build an OSC 7501 report. Pair order mirrors pi-tui: state, app, kind
// (blocked only), msg (only when present). Reports replace the record
// wholesale, so every report repeats app=pi.
export function encodeStatus(
  state: string,
  opts: { app?: string; kind?: string; message?: string } = {},
): string {
  const pairs = [`state=${state}`];
  if (opts.app !== undefined && APP_RE.test(opts.app)) {
    pairs.push(`app=${opts.app}`);
  }
  if (state === "blocked" && opts.kind) {
    pairs.push(`kind=${opts.kind}`);
  }
  if (opts.message) {
    pairs.push(`msg=${Buffer.from(opts.message, "utf8").toString("base64")}`);
  }
  return `${ESC}]7501;${pairs.join(":")}${ESC}\\`;
}

// Parse a single OSC 7501 report into a record, or null when the input is not
// exactly one complete report (e.g. a TUI frame that merely contains one).
export function decodeStatus(chunk: string): StatusRecord | null {
  const match = String(chunk).match(STATUS_REPORT_RE);
  if (!match) {
    return null;
  }
  const record: StatusRecord = { state: "" };
  for (const pair of match[1].split(":")) {
    const eq = pair.indexOf("=");
    if (eq === -1) continue;
    const key = pair.slice(0, eq);
    const value = pair.slice(eq + 1);
    if (key === "state") record.state = value;
    else if (key === "app") record.app = value;
    else if (key === "kind") record.kind = value;
    else if (key === "msg") record.message = Buffer.from(value, "base64").toString("utf8");
  }
  return record.state ? record : null;
}

// True when the input is exactly one complete OSC 7501 status report.
export function isStatusReport(chunk: unknown): boolean {
  return decodeStatus(toUtf8String(chunk)) !== null;
}

function isBlockedEvent(event: unknown): event is { active: boolean } {
  if (typeof event !== "object" || event === null || Array.isArray(event)) return false;

  return (
    Object.prototype.hasOwnProperty.call(event, "active") &&
    typeof (event as { active?: unknown }).active === "boolean"
  );
}

function toUtf8String(chunk: unknown): string | undefined {
  if (typeof chunk === "string") return chunk;
  if (chunk instanceof Uint8Array) return Buffer.from(chunk).toString("utf8");
  return undefined;
}
