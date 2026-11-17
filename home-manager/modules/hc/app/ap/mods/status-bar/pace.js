// Claude plan pacing: how much of a window's remaining percentage is left per unit of time, counted in
// AP's working hours. The weekly window divides over fractional working days (08:00-20:00, Monday-Friday),
// the rolling 5-hour window over plain elapsed hours.
//
// Nothing is imported here on purpose: the status bar mod loads this file in Herdr's runtime, and the bun
// unit check loads the same file outside it.

// AP's working window. The status bar's weekly budget changes the day it changes.
export const WORK = { startHour: 8, endHour: 20, workdays: [1, 2, 3, 4, 5] };

// A span this short turns left-per-unit into a four-digit number, so no budget is shown for it.
export const MIN_SPAN_HOURS = 0.05;

const HOUR_MS = 3600000;

// Fractional hours from now to the reset, 0 once the reset has passed or when it is missing.
export function hoursLeft(nowMs, resetsSec) {
  const resetMs = Number(resetsSec) * 1000;
  if (!Number.isFinite(resetMs)) return 0;
  return Math.max(0, resetMs - nowMs) / HOUR_MS;
}

// Hours of [now, reset] that fall inside the working window, summed day by day in local time. Weekend days
// contribute nothing, and a reset outside working hours truncates its last day instead of rounding it up.
export function workHoursLeft(nowMs, resetsSec, work = WORK) {
  const resetMs = Number(resetsSec) * 1000;
  if (!Number.isFinite(resetMs) || resetMs <= nowMs) return 0;

  let hours = 0;
  const day = new Date(nowMs);
  day.setHours(0, 0, 0, 0);

  while (day.getTime() <= resetMs) {
    if (work.workdays.includes(day.getDay())) {
      const open = new Date(day).setHours(work.startHour, 0, 0, 0);
      const close = new Date(day).setHours(work.endHour, 0, 0, 0);
      const lo = Math.max(nowMs, open);
      const hi = Math.min(resetMs, close);
      if (hi > lo) hours += (hi - lo) / HOUR_MS;
    }
    day.setDate(day.getDate() + 1);
  }

  return hours;
}

// What remains of a window's percentage, clamped to 0..100.
export function leftPercent(used) {
  const value = Number(used);
  if (!Number.isFinite(value)) return 0;
  return Math.min(100, Math.max(0, 100 - value));
}

// Display data for one window, or null when a per-unit budget would be meaningless. `span` is expressed in
// `unit` ("h" or "d") and `perUnit` stays unrounded so the caller decides how to show it.
export function paceFor(key, window, nowMs, work = WORK) {
  const used = Number(window?.used);
  if (!Number.isFinite(used)) return null;

  const resetMs = Number(window?.resets) * 1000;
  if (!Number.isFinite(resetMs) || resetMs <= nowMs) return null;

  let spanHours;
  let unit;
  if (key === "five_hour") {
    spanHours = hoursLeft(nowMs, window.resets);
    unit = "h";
  } else if (key === "seven_day") {
    spanHours = workHoursLeft(nowMs, window.resets, work);
    unit = "d";
  } else {
    return null;
  }

  if (!(spanHours >= MIN_SPAN_HOURS)) return null;

  const left = leftPercent(used);
  const span = unit === "d" ? spanHours / (work.endHour - work.startHour) : spanHours;

  return { left, span, unit, perUnit: left / span };
}
