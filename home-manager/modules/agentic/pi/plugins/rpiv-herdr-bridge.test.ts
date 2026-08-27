import { expect, test } from "bun:test";

type EventHandler = (event: unknown) => void;

type EmittedEvent = { name: string; payload: unknown };

function createPi() {
  const handlers = new Map<string, EventHandler>();
  const emitted: EmittedEvent[] = [];
  return {
    events: {
      on: (name: string, handler: EventHandler) => handlers.set(name, handler),
      emit: (name: string, payload: unknown) => {
        emitted.push({ name, payload });
        handlers.get(name)?.(payload);
      },
    },
    emitted,
  };
}

test("translates RPIV blocked events into exact Herdr blocked payloads", async () => {
  const pi = createPi();
  const { default: registerBridge } = await import(`./rpiv-herdr-bridge.ts?${crypto.randomUUID()}`);
  registerBridge(pi);

  pi.events.emit("rpiv:ask-user:blocked", { active: true });
  pi.events.emit("rpiv:ask-user:blocked", { active: false });

  expect(pi.emitted.filter(({ name }) => name === "herdr:blocked")).toEqual([
    { name: "herdr:blocked", payload: { active: true } },
    { name: "herdr:blocked", payload: { active: false } },
  ]);
  expect(pi.emitted
    .filter(({ name }) => name === "herdr:blocked")
    .map(({ payload }) => Object.keys(payload))).toEqual([["active"], ["active"]]);
});

test("ignores malformed RPIV blocked events", async () => {
  const pi = createPi();
  const { default: registerBridge } = await import(`./rpiv-herdr-bridge.ts?${crypto.randomUUID()}`);
  registerBridge(pi);

  for (const payload of [
    undefined,
    null,
    {},
    { active: "true" },
    { active: 1 },
    { active: null },
    "active",
    [],
  ]) {
    pi.events.emit("rpiv:ask-user:blocked", payload);
  }

  expect(pi.emitted.filter(({ name }) => name === "herdr:blocked")).toEqual([]);
});

test("ignores unrelated Pi events", async () => {
  const pi = createPi();
  const { default: registerBridge } = await import(`./rpiv-herdr-bridge.ts?${crypto.randomUUID()}`);
  registerBridge(pi);

  pi.events.emit("pi:other-event", { active: true });

  expect(pi.emitted.filter(({ name }) => name === "herdr:blocked")).toEqual([]);
});
