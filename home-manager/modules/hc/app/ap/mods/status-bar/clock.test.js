// Unit suite for the clock spelling. Instants are built from local wall-clock fields so the expectations hold in
// any timezone; only the module under test and bun's runner are imported.

import { describe, expect, test } from "bun:test";
import { clockAt, resetText } from "./clock.js";

const MINUTE_MS = 60000;
const at = (y, m, d, h, min) => new Date(y, m, d, h, min, 0, 0).getTime();
const sec = (ms) => Math.floor(ms / 1000);

// Friday 20 November 2026, 09:00.
const FRI_0900 = at(2026, 10, 20, 9, 0);

describe("clockAt", () => {
  test("prints both fields padded in 24-hour time", () => {
    expect(clockAt(at(2026, 10, 20, 17, 5))).toBe("17:05");
    expect(clockAt(at(2026, 10, 20, 7, 5))).toBe("07:05");
  });

  test("keeps the :00 minutes", () => {
    expect(clockAt(at(2026, 10, 20, 17, 0))).toBe("17:00");
  });

  test("renders midnight and noon", () => {
    expect(clockAt(at(2026, 10, 20, 0, 30))).toBe("00:30");
    expect(clockAt(at(2026, 10, 20, 12, 0))).toBe("12:00");
  });
});

describe("resetText", () => {
  test("names the clock time when the reset is later the same day", () => {
    expect(resetText(sec(at(2026, 10, 20, 17, 50)), FRI_0900)).toBe("resets 17:50");
  });

  test("names the day when the reset falls on another day", () => {
    expect(resetText(sec(at(2026, 10, 22, 7, 0)), FRI_0900)).toBe("resets Sun 07:00");
  });

  test("compares days against the supplied now, not the wall clock", () => {
    expect(resetText(sec(at(2026, 10, 20, 17, 50)), at(2026, 10, 19, 9, 0))).toBe("resets Fri 17:50");
  });

  test("counts the minutes under an hour", () => {
    expect(resetText(sec(FRI_0900 + 12 * MINUTE_MS), FRI_0900)).toBe("resets in 12m");
  });

  test("rounds a few seconds left up to one minute", () => {
    expect(resetText(sec(FRI_0900 + 20 * 1000), FRI_0900)).toBe("resets in 1m");
  });

  test("names the clock once the reset has passed", () => {
    expect(resetText(sec(FRI_0900 - MINUTE_MS), FRI_0900)).toBe("reset at 08:59");
  });
});
