import { expect, test } from "bun:test";
import { readMachineOrder, resolveMachineOrder, moveMachine, trackMachinePress, releaseMachinePress } from "./machine-order.js";

test("missing or invalid preferences keep the local-first, alphabetical default", () => {
  for (const stored of [null, "{", "null", '{}', '[false, 42, ""]']) {
    expect(resolveMachineOrder(readMachineOrder(stored), ["z", "a", "z"])).toEqual({
      all: [null, "a", "z"],
      visible: [null, "a", "z"],
    });
  }
});

test("valid IDs survive loading once, including local and a remote named local", () => {
  expect(readMachineOrder('["local", false, null, "z", "local", null, {}]')).toEqual(["local", null, "z"]);
});

test("new machines append after saved ones while absent IDs keep their slots", () => {
  const saved = [null, "away", "z", "a"];
  const order = resolveMachineOrder(saved, ["z", "c", "b", "a"]);
  expect(order).toEqual({
    all: [null, "away", "z", "a", "b", "c"],
    visible: [null, "z", "a", "b", "c"],
  });

  const moved = moveMachine(order, "z", "a");
  expect(moved).toEqual([null, "away", "a", "z", "b", "c"]);
  expect(resolveMachineOrder(moved, ["a", "z", "b", "c"]).visible).toEqual([null, "a", "z", "b", "c"]);
  expect(resolveMachineOrder(moved, ["away", "z", "a", "c", "b"]).visible).toEqual(moved);
  expect(saved).toEqual([null, "away", "z", "a"]);
  expect(order.visible).toEqual([null, "z", "a", "b", "c"]);
});

test("local moves down or back up using the same insertion rules as remote machines", () => {
  const order = resolveMachineOrder([], ["z", "a"]);
  const moved = moveMachine(order, null, "z");
  expect(moved).toEqual(["a", "z", null]);
  expect(moveMachine(resolveMachineOrder(moved, ["z", "a"]), null, "a")).toEqual([null, "a", "z"]);
});

test("drops on the source or involving unavailable IDs have no order to save", () => {
  const order = resolveMachineOrder([null, "away", "a"], ["a"]);
  for (const [source, target] of [[null, null], ["a", "a"], ["away", null], ["a", "away"], [undefined, "a"], ["a", "unknown"]]) {
    expect(moveMachine(order, source, target)).toBeNull();
  }
});

test("small movement stays a click; a drag returning to its source does not fold", () => {
  const press = { source: null, y: 40, dragging: false, over: undefined };
  expect(trackMachinePress(press, null, 42)).toBe(press);
  expect(releaseMachinePress(press, null, 42)).toBe("fold");
  expect(releaseMachinePress(press, "remote", 42)).toBeNull();

  const dragging = trackMachinePress(press, "remote", 70);
  expect(dragging).toEqual({ ...press, dragging: true, over: "remote" });
  const returned = trackMachinePress(dragging, null, 40);
  expect(returned).toEqual({ ...press, dragging: true });
  expect(releaseMachinePress(returned, null, 40)).toBeNull();
});

test("movement over sidebar content clears the indicator, and local is a valid target", () => {
  const press = { source: "remote", y: 70, dragging: false, over: undefined };
  const dragging = trackMachinePress(press, null, 40);
  expect(dragging.over).toBeNull();
  expect(releaseMachinePress(dragging, null, 40)).toBe("move");
  const overContent = trackMachinePress(dragging, undefined, 51);
  expect(overContent).toEqual({ ...press, dragging: true });
  expect(releaseMachinePress(overContent, undefined, 51)).toBeNull();
});
