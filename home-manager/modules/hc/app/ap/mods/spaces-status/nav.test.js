import { expect, test } from "bun:test";
import { visibleNavOrder, step } from "./nav.js";

// A display item as folders.js emits it: kind "row" carries the row and the folder it sits in;
// kind "folder" is a header and never navigable.
const row = (id, machine = null, extra = {}, folder = null) => ({
  kind: "row",
  row: { w: { id, machine }, ...extra },
  folder,
});
const folder = (name, count = 0) => ({ kind: "folder", name, count });

test("visible rows are mains and non-hidden kids, in section order, in draw order", () => {
  const sections = [
    { machine: null, items: [folder("velix", 2), row("m1", null, {}, "velix"), row("k1", null, { tree: "├─", hidden: false }, "velix"), row("m2", null, {}, null)] },
    { machine: "away", items: [row("m3", "away")] },
  ];
  expect(visibleNavOrder(sections, new Set())).toEqual(["m1", "k1", "m2", "m3"]);
});

test("hidden rows are skipped; mains of folded repos stay", () => {
  const sections = [
    { machine: null, items: [row("m1"), row("k1", null, { tree: "└─", hidden: true }), row("k2", null, { tree: "└─", hidden: true })] },
  ];
  expect(visibleNavOrder(sections, new Set())).toEqual(["m1"]);
});

test("collapsed sections are skipped entirely (local null included)", () => {
  const sections = [
    { machine: null, items: [row("m1")] },
    { machine: "away", items: [row("m2", "away")] },
    { machine: "z", items: [row("m3", "z")] },
  ];
  expect(visibleNavOrder(sections, new Set([null, "away"]))).toEqual(["m3"]);
  expect(visibleNavOrder(sections, new Set(["away"]))).toEqual(["m1", "m3"]);
});

test("collapsed folders hide their rows; headers are never navigable", () => {
  const sections = [
    { machine: null, items: [folder("velix", 2), row("a", null, {}, "velix"), row("b", null, {}, "velix"), row("o", null, {}, null)] },
  ];
  expect(visibleNavOrder(sections, new Set(), new Set(["velix"]))).toEqual(["o"]);
  expect(visibleNavOrder(sections, new Set(), new Set())).toEqual(["a", "b", "o"]);
});

test("sections are in display order; the order parameter is not consulted", () => {
  const sections = [
    { machine: "z", items: [row("m2", "z")] },
    { machine: null, items: [row("m1")] },
  ];
  expect(visibleNavOrder(sections, new Set())).toEqual(["m2", "m1"]);
});

test("step walks forward and backward across section boundaries, with no wrap", () => {
  const sections = [
    { machine: null, items: [row("m1"), row("k1", null, { tree: "└─", hidden: false })] },
    { machine: "away", items: [row("m2", "away")] },
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
    { machine: null, items: [row("m1"), row("k1", null, { tree: "└─", hidden: true }), row("m2")] },
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
