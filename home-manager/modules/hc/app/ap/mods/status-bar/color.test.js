// Unit suite for the usage tier scale. Only the module under test and bun's runner are imported, matching the pacing
// and clock suites beside it.

import { describe, expect, test } from "bun:test";
import { CRIT_AT, WARN_AT, tierOf } from "./color.js";

describe("tierOf", () => {
  test("stays normal one point above the warning threshold", () => {
    expect(tierOf(26)).toBe("normal");
    expect(tierOf(100)).toBe("normal");
    expect(tierOf(50)).toBe("normal");
  });

  test("warns from the warning threshold down to above the critical one", () => {
    expect(tierOf(25)).toBe("warn");
    expect(tierOf(20)).toBe("warn");
    expect(tierOf(11)).toBe("warn");
  });

  test("goes critical at the critical threshold and below", () => {
    expect(tierOf(10)).toBe("crit");
    expect(tierOf(1)).toBe("crit");
    expect(tierOf(0)).toBe("crit");
    expect(tierOf(-3)).toBe("crit");
  });

  test("never alarms on a value it cannot read", () => {
    expect(tierOf(Number.NaN)).toBe("normal");
    expect(tierOf(undefined)).toBe("normal");
    expect(tierOf(null)).toBe("normal");
    expect(tierOf("10")).toBe("normal");
    expect(tierOf(Number.POSITIVE_INFINITY)).toBe("normal");
  });

  test("exposes the thresholds the bar documents", () => {
    expect(WARN_AT).toBe(25);
    expect(CRIT_AT).toBe(10);
  });
});
