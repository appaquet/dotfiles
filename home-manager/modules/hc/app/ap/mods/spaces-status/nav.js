// Navigation along the sidebar's visible rows. Pure — no herdr imports, so bun
// can test it directly.

// visibleNavOrder(sections, folded, folderFolders): `sections` is in display order (the saved
// machine order); each section holds the display items (folder headers and rows in draw order, from
// folders.js). Returns the ids of the rows actually drawn: mains and visible worktrees, skipping rows
// of collapsed sections, collapsed folders and hidden (repo-folded) rows.
export function visibleNavOrder(sections, folded, folderFolders = new Set()) {
  const ids = [];
  for (const { machine, items } of sections) {
    if (folded?.has(machine)) continue;
    for (const it of items) {
      if (it.kind !== "row") continue;
      if (it.row.hidden) continue;
      if (it.folder && folderFolders?.has(it.folder)) continue;
      ids.push(it.row.w.id);
    }
  }
  return ids;
}

// step(order, current, direction, anchor): the id after `current` for direction 1
// (before it for -1), with no wrap — null at the ends. `current` is the active
// space id; `anchor` is the id to step from when `current` is not in the order
// (a space hidden inside a folded group, where the caller passes that group's
// visible main row). Unknown current and anchor: null.
export function step(order, current, direction, anchor) {
  if (!order.length) return null;
  if (order.includes(current)) {
    const i = order.indexOf(current);
    const j = i + direction;
    return j >= 0 && j < order.length ? order[j] : null;
  }
  if (!anchor || !order.includes(anchor)) return null;
  const i = order.indexOf(anchor);
  const j = i + direction;
  return j >= 0 && j < order.length ? order[j] : null;
}
