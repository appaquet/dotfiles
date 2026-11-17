// Window status bar: machine, branch, agents count, Claude plan usage and the palette hint. A clone of the
// shipped `workspace-status` with one added segment: what remains of the 5-hour and weekly Claude limits, and
// the spend budget per remaining hour or working day. The percentages come from the statusline payloads
// `tap.sh` saves (see data.js, copied from PostHog's claude-usage mod); the budget from pace.js. Being always
// on screen, it also records when each space was last shown, for the `goto` picker's ordering.

import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, theme, run, window, keys, shared, setShared } from "herdr";
import { WINDOWS, limits, ensureDataDir, prune } from "./data.js";
import { WORK, leftPercent, paceFor } from "./pace.js";

const REFRESH_EVERY = 10000;
const PRUNE_EVERY = 3600000;
const DIM_AFTER = 3600000;
const SEEN = "status-bar.usage-seen";
const SPACE_SEEN = "space.seen";
const SHOWN = ["five_hour", "seven_day"];
// Tooltip nouns for those two windows; `data.js` keeps the shorter labels the bar itself shows.
const NAMES = { five_hour: "5-hour", seven_day: "Weekly" };
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export default class WorkspaceStatus extends View {
  init(_props, cx) {
    this.usage = {};
    ensureDataDir().then(() => prune()).catch(() => null);
    cx.timer.every(PRUNE_EVERY, () => prune().catch(() => null));
    cx.timer.every(REFRESH_EVERY, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      const data = await limits().catch(() => null);
      if (data) {
        this.usage = data.windows;
        this.remember();
      }
      cx.notify();
    });
  }

  // Payloads only change on a Claude reply, so the last time the numbers moved tells how stale they are.
  // Kept in shared state so a restart doesn't make old numbers look fresh.
  remember() {
    const sig = JSON.stringify(this.usage);
    if (shared(SEEN)?.sig !== sig) setShared(SEEN, { sig, at: Date.now() });
  }

  // Shared "space.seen": space id -> when it was last shown, read by the `goto` picker. Render runs on every
  // live-data change, so writing only when the shown space changes keeps the write from re-rendering in a loop.
  recordShown(space) {
    if (!space || space.id === this.lastShown) return;
    this.lastShown = space.id;
    const ids = new Set(spaces().map((s) => s.id));
    const seen = Object.fromEntries(Object.entries(shared(SPACE_SEEN) ?? {}).filter(([id]) => ids.has(id)));
    setShared(SPACE_SEEN, { ...seen, [space.id]: Date.now() });
  }

  // The palette key as actually bound, not a hardcoded one; without a
  // binding the hint stays useful ("commands") instead of lying.
  hint(t) {
    const mac = window()?.platform === "macos";
    const mod = { cmd: mac ? "⌘" : "Ctrl+", ctrl: mac ? "⌃" : "Ctrl+", shift: mac ? "⇧" : "Shift+", alt: mac ? "⌥" : "Alt+", option: mac ? "⌥" : "Alt+" };
    const b = keys().find((k) => k.section === "global" && k.action === "app.palette");
    const parts = b && b.keys.endsWith("--") ? [...b.keys.slice(0, -2).split("-"), "-"] : b?.keys.split("-");
    const key = parts && parts.map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join("");
    return key ? `${key}  commands` : "commands";
  }

  // `5h 82% (49%/h) · week 62% (23%/d)`: what remains of each window, with the spend budget per remaining
  // hour or working day in parentheses. Reset times and leftovers live in the tooltip; null when nothing was
  // ever tapped.
  usageSegment(t) {
    const shown = WINDOWS.filter((w) => SHOWN.includes(w.key) && this.usage[w.key]);
    if (shown.length === 0) return null;

    const now = Date.now();
    const pace = (w) => paceFor(w.key, this.usage[w.key], now);
    const text = shown.map((w) => {
      const v = this.usage[w.key];
      if (v.resets * 1000 <= now) return `${w.label} --`;
      const p = pace(w);
      const left = Math.round(p ? p.left : leftPercent(v.used));
      return p ? `${w.label} ${left}% (${Math.round(p.perUnit)}%/${p.unit})` : `${w.label} ${left}%`;
    }).join(" · ");
    const tip = shown.flatMap((w) => {
      const p = pace(w);
      const lines = [`${w.title}: ${resetText(this.usage[w.key].resets)}`];
      if (p) lines.push(`${NAMES[w.key] ?? w.label} left: ${Math.round(p.left)}% over ${spanText(p.span, p.unit)}`);
      return lines;
    });
    tip.push(workText());
    const at = shared(SEEN)?.at;
    const old = Boolean(at) && now - at > DIM_AFTER;

    return div().id("usage").text_color(old ? t.dim : t.muted).tooltip(tip.join("\n")).child(text);
  }

  render() {
    const t = theme();
    const space = spaces().find(s => s.active);
    this.recordShown(space);
    const list = agents();
    const needs = list.filter(a => a.status === "blocked").length;
    const usage = this.usageSegment(t);
    const label = (icon, text) => h_flex().gap(6).items_center().child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    return h_flex().size_full().px(14).gap(16).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), el => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, el => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(div().flex_1())
      .when(Boolean(usage), el => el.child(usage))
      .child(div().id("palette").text_color(t.dim).on_click(() => run("app.palette")).child(this.hint(t)));
  }
}

// Reset time as `resets 3pm`, `resets Fri 9:30am` or `resets in 12m`; taken from PostHog's claude-usage mod.
function resetText(sec) {
  const at = sec * 1000;
  const left = at - Date.now();
  if (left <= 0) return `reset at ${clock(new Date(at))}`;
  if (left < 3600000) return `resets in ${Math.max(1, Math.round(left / 60000))}m`;
  const d = new Date(at);
  return `resets ${d.toDateString() === new Date().toDateString() ? "" : `${DAYS[d.getDay()]} `}${clock(d)}`;
}

function clock(d) {
  const h = d.getHours();
  const m = String(d.getMinutes()).padStart(2, "0");
  return `${h % 12 || 12}${m === "00" ? "" : `:${m}`}${h < 12 ? "am" : "pm"}`;
}

// `1h 40m` for an hour span, `2.7 working days` for a working-day span.
function spanText(span, unit) {
  if (unit === "d") {
    const days = span.toFixed(1);
    return `${days} working ${days === "1.0" ? "day" : "days"}`;
  }

  const minutes = Math.round(span * 60);
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

// `Working time: 08:00-20:00, Mon-Fri`, derived from WORK so the tooltip cannot drift from that constant.
function workText() {
  const hh = (h) => `${String(h).padStart(2, "0")}:00`;
  const contiguous = WORK.workdays.every((d, i) => i === 0 || d === WORK.workdays[i - 1] + 1);
  const days = contiguous
    ? `${DAYS[WORK.workdays[0]]}-${DAYS[WORK.workdays[WORK.workdays.length - 1]]}`
    : WORK.workdays.map((d) => DAYS[d]).join(", ");

  return `Working time: ${hh(WORK.startHour)}-${hh(WORK.endHour)}, ${days}`;
}
