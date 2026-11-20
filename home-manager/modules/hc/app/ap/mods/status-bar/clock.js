// Clock spelling for the status bar: the 24-hour `HH:MM` both the bar segment and the tooltip print, the day names
// a reset may carry, and the tooltip's reset sentence built on them. Nothing is imported here on purpose: the status
// bar mod loads this file in Herdr's runtime, and the bun unit check loads the same file outside it.

const HOUR_MS = 3600000;

export const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// Local `HH:MM` with both fields padded. Minutes are always printed, so `17:00` cannot read as `17`.
export function clockAt(ms) {
  const d = new Date(ms);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

// Reset time as `resets 17:50`, `resets Fri 07:00` or `resets in 12m`; once the reset has passed it names the clock
// instead. `nowMs` is a parameter so the unit suite can pin it; call sites pass the reset seconds alone.
export function resetText(sec, nowMs = Date.now()) {
  const at = Number(sec) * 1000;
  const left = at - nowMs;
  if (left <= 0) return `reset at ${clockAt(at)}`;
  if (left < HOUR_MS) return `resets in ${Math.max(1, Math.round(left / 60000))}m`;

  const sameDay = new Date(at).toDateString() === new Date(nowMs).toDateString();
  return `resets ${sameDay ? "" : `${DAYS[new Date(at).getDay()]} `}${clockAt(at)}`;
}
