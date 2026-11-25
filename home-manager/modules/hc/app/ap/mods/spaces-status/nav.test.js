import { expect, test } from "bun:test";
import { visibleNavOrder, step } from "./nav.js";

// A row as ordered() emits it: w is the space, hidden marks repo-folded rows.
const main = (id, machine = null, extra = {}) => ({ w: { id, machine }, ...extra });
const kid = (id, mainId, machine = null) => ({ w: { id, machine }, tree: "├─", hidden: false, main: mainId });

test("visible rows are mains and non-hidden kids, in section order, in draw order", () => {
  const sections = [
    { machine: null, rows: [main("m1"), kid("k1", "m1"), main("m2")] },
    { machine: "away", rows: [main("m3", "away")] },
  ];
  expect(visibleNavOrder(sections, new Set())).toEqual(["m1", "k1", "m2", "m3"]);
});

test("hidden rows are skipped; mains of folded repos stay", () => {
  const sections = [
    { machine: null, rows: [main("m1"), { ...kid("k1", "m1"), hidden: true }, { ...kid("k2", "m1"), hidden: true }] },
  ];
  expect(visibleNavOrder(sections, new Set())).toEqual(["m1"]);
});

test("collapsed sections are skipped entirely (local null included)", () => {
  const sections = [
    { machine: null, rows: [main("m1")] },
    { machine: "away", rows: [main("m2", "away")] },
    { machine: "z", rows: [main("m3", "z")] },
  ];
  expect(visibleNavOrder(sections, new Set([null, "away"]))).toEqual(["m3"]);
  expect(visibleNavOrder(sections, new Set(["away"]))).toEqual(["m1", "m3"]);
});

test("sections are in display order; the order parameter is not consulted", () => {
  // Order comes from the section list, not from any saved-order reconciliation here.
  const sections = [
    { machine: "z", rows: [main("m2", "z")] },
    { machine: null, rows: [main("m1")] },
  ];
  expect(visibleNavOrder(sections, new Set())).toEqual(["m2", "m1"]);
});

test("step walks forward and backward across section boundaries, with no wrap", () => {
  const sections = [
    { machine: null, rows: [main("m1"), kid("k1", "m1")] },
    { machine: "away", rows: [main("m2", "away")] },
  ];
  const order = visibleNavOrder(sections, new Set());
  expect(order).toEqual(["m1", "k1", "m2"]);
  expect(step(order, "m1", 1)).toBe("k1");
  expect(step(order, "k1", 1)).toBe("m2"); // crosses the section boundary
  expect(step(order, "m2", 1)).toBeNull(); // end: no wrap
  expect(step(order, "m1", -1)).toBeNull();
  expect(step(order, "m2", -1)).toBe("k1");
});

test("step from a hidden space anchors on its visible main row", () => {
  const sections = [
    { machine: null, rows: [main("m1"), { ...kid("k1", "m1"), hidden: true }, main("m2")] },
  ];
  const order = visibleNavOrder(sections, new Set());
  expect(order).toEqual(["m1", "m2"]);
  // k1 is hidden (repo folded): step from its group's main, which is visible.
  expect(step(order, "k1", 1, "m1")).toBe("m2");
  expect(step(order, "k1", -1, "m1")).toBeNull();
  // Anchor at the last visible row: stepping on forward yields null.
  expect(step(["m1"], "k1", 1, "m1")).toBeNull();
});

test("step from an unknown anchor returns null", () => {
  expect(step(["m1", "m2"], "k1", 1, "k1")).toBeNull();
  expect(step(["m1", "m2"], "k1", 1)).toBeNull();
});

test("step on an empty order returns null", () => {
  expect(step([], "m1", 1)).toBeNull();
  expect(step([], "m1", -1, "m1")).toBeNull();
});
