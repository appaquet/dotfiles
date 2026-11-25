// Window status bar: machine, branch, agents count, Claude plan usage and the palette hint. A clone of the
// shipped `workspace-status` with one added segment: one pill per Claude scope — personal and each scoped
// instance — with what remains of the 5-hour and weekly limits and the weekly spend budget per remaining
// working day. The windows are merged per scope, not across scopes: personal and scoped instances share the dump,
// and a scope's pill never shows another scope's numbers. A percentage turns amber at 25% of a window left and
// red at 10% (color.js). The percentages come from the statusline payloads `tap.sh` saves here and on every machine
// herdr-core reports connected (data.js, copied from PostHog's claude-usage mod, for this machine; sources.js and
// remote.js for the others), read at most once a minute and only while the window is active; the budget from
// pace.js. Being always on screen, it also records when each space was last shown, for the `goto` picker's ordering.

import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, theme, run, window, keys, shared, setShared } from "herdr";
import { DAYS, resetText } from "./clock.js";
import { tierOf } from "./color.js";
import { WINDOWS, limits, ensureDataDir, prune } from "./data.js";
import { WORK, leftPercent, paceFor } from "./pace.js";
import { mergeWindows } from "./sources.js";
import { fetchMachine, pollableMachines } from "./remote.js";

const REFRESH_EVERY = 60000;
// How often the window's own active state is looked at, so a read starts when herdr comes back to the front
// instead of up to a minute later.
const WAKE_EVERY = 2000;
const PRUNE_EVERY = 3600000;
const DIM_AFTER = 3600000;
const SEEN = "status-bar.usage-seen";
const SPACE_SEEN = "space.seen";
const SHOWN = ["five_hour", "seven_day"];
// Tooltip nouns for those two windows; `data.js` keeps the shorter labels the bar itself shows.
const NAMES = { five_hour: "5-hour", seven_day: "Weekly" };
// Only the weekly budget earns a place in the bar. The 5-hour one swings from 20%/h on a fresh window to
// 50%/h just before a reset, and there is little to decide with it, so it stays in the tooltip. Its end time does
// earn a place in the bar, since that is what tells how long the window still has to run.
const BAR_BUDGET = "seven_day";
// Size of the small parentheticals a window can carry: its spend budget, and the 5-hour window's end time.
const DETAIL_SIZE = 11.2;
// Theme tokens for the two low-usage tiers: amber and red, the ANSI pair the tab bar also uses for CI state. The
// healthy tier keeps the segment's own muted colour, so the bar only stands out once a window is nearly spent.
const TIER_TOKEN = { normal: "muted", warn: "ansi3", crit: "ansi1" };

export default class WorkspaceStatus extends View {
  init(_props, cx) {
    this.usage = {};
    this.local = {}; // this machine's windows
    this.remote = {}; // machine -> the windows its last successful read reported
    this.refreshedAt = 0;
    this.seenActive = false;
    this.refreshing = false;
    ensureDataDir().then(() => prune()).catch(() => null);
    cx.timer.every(PRUNE_EVERY, () => prune().catch(() => null));
    cx.timer.every(WAKE_EVERY, (cx) => this.wake(cx));
    this.wake(cx);
  }

  // Payloads only move on a Claude reply, so one read a minute is enough; nothing is read at all while herdr is in
  // the background, and coming back to the front reads at once.
  wake(cx) {
    if (!window()?.active) {
      this.seenActive = false;
      return;
    }
    if (!this.seenActive || Date.now() - this.refreshedAt >= REFRESH_EVERY) this.refresh(cx);
    this.seenActive = true;
  }

  // This machine's files plus one round trip per connected machine, all at once. The reports are rebuilt every time, so
  // a machine that is gone, asleep or renamed stops contributing instead of pinning the bar at its last numbers; and
  // only one refresh runs at a time, so alt-tabbing cannot stack polls.
  refresh(cx) {
    if (this.refreshing) return;
    this.refreshing = true;
    this.refreshedAt = Date.now();
    cx.spawn(async (cx) => {
      try {
        const mine = await limits().catch(() => null);
        if (mine) this.local = mine.windows;

        const machines = await pollableMachines();
        const reports = await Promise.all(machines.map((name) => fetchMachine(name)));
        const remote = {};
        machines.forEach((name, i) => {
          if (!reports[i].failed) remote[name] = reports[i].windows;
        });
        this.remote = remote;

        this.usage = mergeWindows(this.local, ...Object.values(this.remote));
        this.remember();
        cx.notify();
      } finally {
        this.refreshing = false;
      }
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

  // One pill per scope: `pers [5h 82% · wk 2% (1%/d)] · vlx [5h 20% · wk 62% (21%/d)]`. Personal and scoped
  // Claude instances share one dump, so the windows are merged per scope and never overwrite each other. The
  // weekly spend budget is a smaller parenthetical; the 5-hour window's end time lives in the tooltip, not the bar.
  // Pills dim after a stale read. null when no payload has ever been tapped.
  usageSegment(t) {
    const scopes = Object.keys(this.usage ?? {}).sort((a, b) =>
      a === "personal" ? -1 : b === "personal" ? 1 : a.localeCompare(b),
    );
    if (scopes.length === 0) return null;

    const now = Date.now();
    const at = shared(SEEN)?.at;
    const old = Boolean(at) && now - at > DIM_AFTER;
    const pills = [];
    const tip = [];
    for (const scope of scopes) {
      const bucket = this.usage[scope];
      const shown = WINDOWS.filter((w) => SHOWN.includes(w.key) && bucket[w.key]);
      if (shown.length === 0) continue;
      const tag = scope === "personal" ? "pers" : scope;
      const chip = tag === "pers" ? t.ansi6 : t.ansi5;
      const parts = [
        div().flex_none().px(4).py(1).rounded(3).bg(old ? t.dim : chip).font_semibold()
          .text_size(9.5).text_color(old ? t.dim : "#0a0f0d").child(tag.toUpperCase()),
      ];
      for (const w of shown) {
        const v = bucket[w.key];
        const p = paceFor(w.key, v, now);
        if (v.resets * 1000 <= now) {
          parts.push(`${w.label} --`);
          continue;
        }
        const pct = Math.round(p ? p.left : leftPercent(v.used));
        if (parts.length > 1) parts.push(" · ");
        parts.push(`${w.label} `);
        parts.push(div().flex_none().text_color(old ? t.dim : t[TIER_TOKEN[tierOf(pct)]]).child(`${pct}%`));
        if (w.key === BAR_BUDGET && p) {
          parts.push(div().flex_none().text_size(DETAIL_SIZE).child(` (${Math.round(p.perUnit)}%/${p.unit})`));
        }
        tip.push(`${tag}: ${w.title}: ${resetText(v.resets)}`);
        if (p) tip.push(`${tag}: ${NAMES[w.key] ?? w.label} left: ${Math.round(p.left)}% over ${spanText(p.span, p.unit)}`);
      }
      pills.push(
        h_flex().id("usage-pill").px(6).py(1.5).rounded(4).border(1).border_color(t.border).bg(t.raised)
          .gap(5).items_center().text_color(old ? t.dim : t.muted).children(parts),
      );
    }
    if (pills.length === 0) return null;
    tip.push(workText());
    return h_flex().id("usage").gap(6).items_center().tooltip(tip.join("\n")).children(pills);
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
