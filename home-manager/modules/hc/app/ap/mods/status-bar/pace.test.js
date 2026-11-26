// Unit suite for the pacing model. Instants are built from local wall-clock fields so the expectations hold
// in any timezone; only the module under test and bun's runner are imported.

import { describe, expect, test } from "bun:test";
import { MIN_SPAN_HOURS, WORK, hoursLeft, leftPercent, paceFor, showBudget, workHoursLeft } from "./pace.js";

const MINUTE_MS = 60000;
const HOUR_MS = 3600000;

const at = (y, m, d, h, min) => new Date(y, m, d, h, min, 0, 0).getTime();
const sec = (ms) => Math.floor(ms / 1000);

// Tuesday 17 November 2026, and the weekly reset AP's payload reports: Friday 20 November, 07:00.
const TUE_1140 = at(2026, 10, 17, 11, 40);
const FRI_0700 = sec(at(2026, 10, 20, 7, 0));

describe("workHoursLeft", () => {
  test("counts only the working hours up to a pre-dawn reset", () => {
    const today = (20 * 60 - (11 * 60 + 40)) / 60;

    expect(workHoursLeft(TUE_1140, FRI_0700)).toBeCloseTo(today + 12 + 12, 5);
    expect(workHoursLeft(TUE_1140, FRI_0700) / 12).toBeCloseTo(2.6944, 3);
  });

  test("counts a whole working day when now precedes the start", () => {
    expect(workHoursLeft(at(2026, 10, 17, 7, 0), sec(at(2026, 10, 17, 20, 0)))).toBeCloseTo(12, 5);
  });

  test("drops the evening and picks up the next morning", () => {
    expect(workHoursLeft(at(2026, 10, 17, 21, 0), sec(at(2026, 10, 18, 9, 0)))).toBeCloseTo(1, 5);
  });

  test("drops weekend days", () => {
    expect(workHoursLeft(at(2026, 10, 21, 10, 0), sec(at(2026, 10, 23, 9, 0)))).toBeCloseTo(1, 5);
  });

  test("clips a same-day span to the working window", () => {
    expect(workHoursLeft(at(2026, 10, 17, 13, 0), sec(at(2026, 10, 17, 15, 30)))).toBeCloseTo(2.5, 5);
  });

  test("returns nothing for a reset before the working day starts", () => {
    expect(workHoursLeft(at(2026, 10, 20, 6, 0), sec(at(2026, 10, 20, 7, 0)))).toBe(0);
  });

  test("returns nothing for a reset in the past", () => {
    expect(workHoursLeft(TUE_1140, sec(TUE_1140 - MINUTE_MS))).toBe(0);
    expect(hoursLeft(TUE_1140, sec(TUE_1140 - MINUTE_MS))).toBe(0);
  });

  test("follows a supplied working window", () => {
    const weekend = { startHour: 9, endHour: 17, workdays: [0, 6] };

    expect(workHoursLeft(at(2026, 10, 21, 10, 0), sec(at(2026, 10, 21, 18, 0)), weekend)).toBeCloseTo(7, 5);
    expect(workHoursLeft(at(2026, 10, 18, 10, 0), sec(at(2026, 10, 18, 18, 0)), weekend)).toBe(0);
  });
});

describe("hoursLeft", () => {
  test("measures plain clock hours", () => {
    expect(hoursLeft(TUE_1140, sec(TUE_1140 + 100 * MINUTE_MS))).toBeCloseTo(100 / 60, 5);
  });
});

describe("paceFor", () => {
  test("divides the weekly remainder by fractional working days", () => {
    const pace = paceFor("seven_day", { used: 38, resets: FRI_0700 }, TUE_1140);

    expect(pace).not.toBeNull();
    expect(pace.left).toBeCloseTo(62, 5);
    expect(pace.unit).toBe("d");
    expect(pace.span).toBeCloseTo(2.6944, 3);
    expect(pace.perUnit).toBeCloseTo(23.01, 1);
  });

  test("divides the five-hour remainder by remaining hours", () => {
    const resets = sec(TUE_1140 + 100 * MINUTE_MS);
    const pace = paceFor("five_hour", { used: 18, resets }, TUE_1140);

    expect(pace).not.toBeNull();
    expect(pace.left).toBeCloseTo(82, 5);
    expect(pace.unit).toBe("h");
    expect(pace.span).toBeCloseTo(100 / 60, 5);
    expect(pace.perUnit).toBeCloseTo(49.2, 1);
  });

  test("clamps the remaining percentage", () => {
    expect(paceFor("five_hour", { used: 105, resets: sec(TUE_1140 + HOUR_MS) }, TUE_1140).left).toBe(0);
    expect(paceFor("five_hour", { used: -5, resets: sec(TUE_1140 + HOUR_MS) }, TUE_1140).left).toBe(100);
  });

  test("returns null when a budget would be meaningless", () => {
    const soon = sec(TUE_1140 + HOUR_MS);
    const tooSoon = sec(TUE_1140 + Math.floor((MIN_SPAN_HOURS * HOUR_MS) / 2));

    expect(paceFor("seven_day", { used: 38, resets: sec(TUE_1140 - MINUTE_MS) }, TUE_1140)).toBeNull();
    expect(paceFor("seven_day", { used: undefined, resets: FRI_0700 }, TUE_1140)).toBeNull();
    expect(paceFor("seven_day", { used: "38", resets: FRI_0700 }, TUE_1140)).not.toBeNull();
    expect(paceFor("five_hour", { used: 18, resets: tooSoon }, TUE_1140)).toBeNull();
    expect(paceFor("spend_limit", { used: 18, resets: soon }, TUE_1140)).toBeNull();
    expect(paceFor("five_hour", { used: 18, resets: 0 }, TUE_1140)).toBeNull();
  });

  test("exposes the working window the bar divides by", () => {
    expect(WORK.startHour).toBe(8);
    expect(WORK.endHour).toBe(20);
    expect(WORK.workdays).toEqual([1, 2, 3, 4, 5]);
    expect(MIN_SPAN_HOURS).toBe(0.05);
  });
});

describe("leftPercent", () => {
  test("clamps to the remaining percentage", () => {
    expect(leftPercent(38)).toBeCloseTo(62, 5);
    expect(leftPercent(105)).toBe(0);
    expect(leftPercent(-5)).toBe(100);
    expect(leftPercent(undefined)).toBe(0);
  });
});

describe("showBudget", () => {
  test("shows the weekly budget when a working day or more remains", () => {
    const pace = paceFor("seven_day", { used: 38, resets: FRI_0700 }, TUE_1140);
    const wholeDay = paceFor("seven_day", { used: 38, resets: sec(at(2026, 10, 17, 20, 0)) }, at(2026, 10, 17, 8, 0));

    expect(showBudget(pace)).toBe(true);
    expect(wholeDay.span).toBeCloseTo(1, 5);
    expect(showBudget(wholeDay)).toBe(true);
  });

  test("hides the weekly budget on the last day", () => {
    const pace = paceFor("seven_day", { used: 63, resets: sec(at(2026, 10, 17, 13, 45)) }, at(2026, 10, 17, 11, 40));

    expect(pace.span).toBeLessThan(1);
    expect(showBudget(pace)).toBe(false);
  });

  test("never shows the five-hour budget", () => {
    const pace = paceFor("five_hour", { used: 18, resets: sec(TUE_1140 + 2 * HOUR_MS) }, TUE_1140);

    expect(pace.span).toBeGreaterThanOrEqual(1);
    expect(showBudget(pace)).toBe(false);
  });

  test("hides a missing pace", () => {
    expect(showBudget(null)).toBe(false);
  });
});
