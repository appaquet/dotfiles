const DRAG_THRESHOLD = 4;

// Machine order is a sidebar preference. Null denotes the local machine.
export function readMachineOrder(stored) {
  try {
    const ids = JSON.parse(stored);
    if (Array.isArray(ids)) {
      return [...new Set(ids.filter(id => id === null || (typeof id === "string" && id.length > 0)))];
    }
  } catch {
    // An unreadable preference must not prevent the sidebar from rendering.
  }
  return [];
}

export function resolveMachineOrder(saved, remotes) {
  const present = new Set([null, ...[...remotes].sort()]);
  const all = [...new Set([...saved, ...present])];
  return { all, visible: all.filter(id => present.has(id)) };
}

export function moveMachine({ all, visible }, source, target) {
  const from = visible.indexOf(source);
  const to = visible.indexOf(target);
  if (from < 0 || to < 0 || from === to) return null;

  const moved = [...visible];
  moved.splice(from, 1);
  moved.splice(to, 0, source);

  // Only replace visible slots so absent machines keep their place when they return.
  const present = new Set(visible);
  let i = 0;
  return all.map(id => present.has(id) ? moved[i++] : id);
}

export function trackMachinePress(press, target, y) {
  const dragging = press.dragging || Math.abs(y - press.y) >= DRAG_THRESHOLD;
  // Undefined is outside a drop target; null is the local machine.
  const over = dragging && target !== press.source ? target : undefined;
  return dragging === press.dragging && over === press.over ? press : { ...press, dragging, over };
}

export function releaseMachinePress(press, target, y) {
  const { dragging, over } = trackMachinePress(press, target, y);
  if (dragging) return over === undefined ? null : "move";
  return target === press.source ? "fold" : null;
}
