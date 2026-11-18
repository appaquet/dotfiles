// Unit suite for the multi-machine usage sources: parsing a machine's separator dump and merging sources. The
// percentages and reset instants are the ones two live payloads carried on 2026/11/18, so a rule change that
// prefers the wrong report shows up as a wrong number here.

import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { SEPARATOR, mergeWindows, parseDump, sourceCommand, windowsOf } from "./sources.js";

const RESET_5H = 1795027200;
const RESET_WEEK = 1795176000;
const NEXT_5H = RESET_5H + 18000;

const window = (used, resets) => ({ used_percentage: used, resets_at: resets });
const payload = (five, week, resets5h = RESET_5H, resetsWeek = RESET_WEEK) => ({
  session_id: `session-${five}-${week}`,
  rate_limits: { five_hour: window(five, resets5h), seven_day: window(week, resetsWeek) },
});

// Runs the command the app would send to another machine, so the shell script itself is covered, not just its text.
const shell = (command, env) => {
  const result = Bun.spawnSync(["sh", "-c", command], { env: { ...process.env, ...env }, stdout: "pipe", stderr: "pipe" });
  return { exitCode: result.exitCode, out: result.stdout.toString(), err: result.stderr.toString() };
};

describe("parseDump", () => {
  test("keeps every payload and drops a junk chunk", () => {
    const text = [JSON.stringify(payload(9, 46)), "{ truncated", JSON.stringify(payload(15, 47)), ""].join(
      `\n${SEPARATOR}\n`,
    );

    const parsed = parseDump(text);

    expect(parsed.map((p) => p.session_id)).toEqual([payload(9, 46).session_id, payload(15, 47).session_id]);
  });

  test("reads an empty or absent dump as no payloads", () => {
    expect(parseDump("")).toEqual([]);
    expect(parseDump(null)).toEqual([]);
    expect(parseDump(`\n${SEPARATOR}\n`)).toEqual([]);
  });
});

describe("windowsOf", () => {
  test("takes the latest window, then the greater value inside it", () => {
    const windows = windowsOf([payload(9, 46), payload(15, 47), payload(12, 47, NEXT_5H)]);

    expect(windows.five_hour).toEqual({ used: 12, resets: NEXT_5H });
    expect(windows.seven_day).toEqual({ used: 47, resets: RESET_WEEK });
  });

  test("ignores payloads without usable rates", () => {
    expect(windowsOf([{ session_id: "x" }, { rate_limits: { five_hour: { used_percentage: "15" } } }])).toEqual({});
  });

  test("falls back to zero when a payload carries no reset instant", () => {
    const windows = windowsOf([{ rate_limits: { spend_limit: { used_percentage: 40 } } }]);

    expect(windows).toEqual({ spend_limit: { used: 40, resets: 0 } });
  });
});

describe("mergeWindows", () => {
  test("prefers the machine that reported the greater value in the same window", () => {
    const here = windowsOf([payload(9, 46)]);
    const deskapp = windowsOf([payload(15, 47)]);

    expect(mergeWindows(here, deskapp)).toEqual({
      five_hour: { used: 15, resets: RESET_5H },
      seven_day: { used: 47, resets: RESET_WEEK },
    });
  });

  test("keeps a newer window over an older, busier one", () => {
    const stale = windowsOf([payload(90, 90, RESET_5H - 18000, RESET_WEEK - 600000)]);
    const fresh = windowsOf([payload(20, 10)]);

    expect(mergeWindows(stale, fresh).five_hour).toEqual({ used: 20, resets: RESET_5H });
  });

  test("merges empty and partial sources without erasing what another one reported", () => {
    const here = windowsOf([payload(9, 46)]);
    const spendOnly = { spend_limit: { used: 55, resets: RESET_WEEK } };

    expect(mergeWindows({}, here, undefined, spendOnly)).toEqual({
      five_hour: { used: 9, resets: RESET_5H },
      seven_day: { used: 46, resets: RESET_WEEK },
      spend_limit: { used: 55, resets: RESET_WEEK },
    });
    expect(mergeWindows({}, {})).toEqual({});
  });
});

describe("sourceCommand", () => {
  test("reads the tapped sessions of another machine with no tool beyond sh and cat", () => {
    expect(sourceCommand).toContain("/data/claude-usage/sessions");
    expect(sourceCommand).toContain("-mtime -8");
    expect(sourceCommand).toContain(`printf`);
    expect(sourceCommand).toContain(SEPARATOR);
    expect(sourceCommand).toContain(`cat "$f"`);
    expect(sourceCommand).not.toContain("jq");
  });

  test("prints the recent payloads of the app home it is given", () => {
    const home = mkdtempSync(join(tmpdir(), "sources-home-"));
    const sessions = join(home, ".config/herdr-app/data/claude-usage/sessions");
    mkdirSync(sessions, { recursive: true });
    writeFileSync(join(sessions, "fresh.json"), JSON.stringify(payload(9, 46)));
    writeFileSync(join(sessions, "stale.json"), JSON.stringify(payload(99, 99)));
    const tenDaysAgo = (Date.now() - 10 * 86400000) / 1000;
    utimesSync(join(sessions, "stale.json"), tenDaysAgo, tenDaysAgo);

    const dump = shell(sourceCommand, { HOME: home, HERDR_APP_HOME: "" });

    expect(dump.exitCode).toBe(0);
    expect(parseDump(dump.out).map((p) => p.session_id)).toEqual([payload(9, 46).session_id]);
  });

  test("follows HERDR_APP_HOME when the machine sets it", () => {
    const home = mkdtempSync(join(tmpdir(), "sources-home-"));
    const moved = mkdtempSync(join(tmpdir(), "sources-moved-"));
    const sessions = join(moved, "data/claude-usage/sessions");
    mkdirSync(sessions, { recursive: true });
    writeFileSync(join(sessions, "moved.json"), JSON.stringify(payload(15, 47)));

    const dump = shell(sourceCommand, { HOME: home, HERDR_APP_HOME: moved });

    expect(parseDump(dump.out).map((p) => p.session_id)).toEqual([payload(15, 47).session_id]);
  });

  test("prints nothing when the machine has no payloads", () => {
    const home = mkdtempSync(join(tmpdir(), "sources-home-"));

    const dump = shell(sourceCommand, { HOME: home, HERDR_APP_HOME: "" });

    expect(dump.exitCode).toBe(0);
    expect(parseDump(dump.out)).toEqual([]);
  });
});
