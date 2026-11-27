import { describe, expect, test } from "bun:test";

// @ts-expect-error -- the module ships plain JS with no type declarations
import { fitScale, stepScale, isOverflowing, panStartAllowed, MIN_ZOOM, MAX_ZOOM, ZOOM_STEP } from "./show-me-diagrams.js";

describe("fitScale", () => {
  test("never enlarges a small diagram beyond natural size", () => {
    // 168x146 natural diagram with plenty of frame room stays at 1.
    expect(fitScale(168, 146, 630, 604)).toBe(1);
    // A small width term also never exceeds 1.
    expect(fitScale(100, 100, 200, 200)).toBe(1);
  });

  test("fits both dimensions by the tighter term", () => {
    // 168x1081 tall diagram in a 631x604 frame is height-bound.
    expect(fitScale(168, 1081, 631, 604)).toBeCloseTo(604 / 1081, 5);
    // 1512x61 wide diagram in a 641x604 frame is width-bound.
    expect(fitScale(1512, 61, 641, 604)).toBeCloseTo(641 / 1512, 5);
  });

  test("shrinks when the frame is smaller than the diagram", () => {
    expect(fitScale(800, 400, 300, 300)).toBeCloseTo(300 / 800, 5);
  });

  test("falls back to 1 for zero-sized inputs", () => {
    expect(fitScale(0, 100, 100, 100)).toBe(1);
    expect(fitScale(100, 100, 0, 100)).toBe(1);
    expect(fitScale(100, 0, 100, 100)).toBe(1);
    expect(fitScale(100, 100, 100, 0)).toBe(1);
  });
});

describe("stepScale", () => {
  test("steps by the zoom factor", () => {
    expect(stepScale(1, ZOOM_STEP)).toBeCloseTo(1.25, 5);
    expect(stepScale(1, 1 / ZOOM_STEP)).toBeCloseTo(0.8, 5);
  });

  test("clamps to the zoom bounds", () => {
    expect(stepScale(MAX_ZOOM, ZOOM_STEP)).toBe(MAX_ZOOM);
    expect(stepScale(MIN_ZOOM, 1 / ZOOM_STEP)).toBe(MIN_ZOOM);
    expect(stepScale(2, 10)).toBe(MAX_ZOOM);
    expect(stepScale(0.5, 0.1)).toBe(MIN_ZOOM);
  });

  test("keeps the current scale on a non-finite result", () => {
    expect(stepScale(1, Infinity)).toBe(1);
  });
});

describe("constants", () => {
  test("zoom bounds are ordered and the step is greater than 1", () => {
    expect(MIN_ZOOM).toBeGreaterThan(0);
    expect(MIN_ZOOM).toBeLessThan(MAX_ZOOM);
    expect(ZOOM_STEP).toBeGreaterThan(1);
  });
});

describe("isOverflowing", () => {
  test("is false when both axes fit", () => {
    expect(isOverflowing({ scrollHeight: 604, clientHeight: 604, scrollWidth: 800, clientWidth: 800 })).toBe(false);
  });

  test("is true when the diagram exceeds the frame in either axis", () => {
    expect(isOverflowing({ scrollHeight: 605, clientHeight: 604, scrollWidth: 800, clientWidth: 800 })).toBe(true);
    expect(isOverflowing({ scrollHeight: 604, clientHeight: 604, scrollWidth: 801, clientWidth: 800 })).toBe(true);
  });

  test("is false when exactly at the boundary", () => {
    expect(isOverflowing({ scrollHeight: 604, clientHeight: 604, scrollWidth: 800, clientWidth: 800 })).toBe(false);
  });
});

describe("panStartAllowed", () => {
  test("starts on the figure background or non-text SVG surface", () => {
    expect(panStartAllowed({ insideFigure: true, insideText: false })).toBe(true);
  });

  test("never hijacks text selection", () => {
    expect(panStartAllowed({ insideFigure: true, insideText: true })).toBe(false);
  });

  test("never starts outside the figure", () => {
    expect(panStartAllowed({ insideFigure: false, insideText: false })).toBe(false);
    expect(panStartAllowed({ insideFigure: false, insideText: true })).toBe(false);
  });
});
