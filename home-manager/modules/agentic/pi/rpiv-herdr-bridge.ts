import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type BlockedEvent = { active: boolean };

export default function registerRpivHerdrBridge(pi: ExtensionAPI): void {
  pi.events.on("rpiv:ask-user:blocked", (event: unknown) => {
    if (!isBlockedEvent(event)) return;
    pi.events.emit("herdr:blocked", { active: event.active });
  });
}

function isBlockedEvent(event: unknown): event is BlockedEvent {
  if (typeof event !== "object" || event === null || Array.isArray(event)) return false;

  return (
    Object.prototype.hasOwnProperty.call(event, "active") &&
    typeof (event as { active?: unknown }).active === "boolean"
  );
}
