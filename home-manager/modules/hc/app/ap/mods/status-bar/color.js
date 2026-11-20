// Tier scale for the status bar's Claude usage segment: how much of a window is left, as a name the view turns into a
// colour. The bar prints a rounded percentage, so the tier is taken from that same printed number; a figure reading 10%
// and a tier saying "healthy" would contradict each other. Nothing is imported here on purpose: the status bar mod loads
// this file in Herdr's runtime, and the bun unit check loads the same file outside it.

// Remaining percentage at or below which a window warns, and at or below which it is critical.
export const WARN_AT = 25;
export const CRIT_AT = 10;

// "crit", "warn" or "normal" for a remaining percentage. Only a finite number is read: the bar always passes the
// rounded figure it prints, so a missing or malformed value stays normal instead of painting an alarm.
export function tierOf(left) {
  if (typeof left !== "number" || !Number.isFinite(left)) return "normal";
  if (left <= CRIT_AT) return "crit";
  if (left <= WARN_AT) return "warn";
  return "normal";
}
