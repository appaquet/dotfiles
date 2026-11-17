// Go to a space. A popup listing spaces, never their tabs: spaces with agents come first by status (needs you,
// finished, working, idle), quiet spaces (no status) fold into "earlier"; within each, the most recently shown
// space comes first (shared "space.seen", recorded by the status-bar mod). Opens on the first space other than the
// current one. Worktree spaces show their parent space first, as the sidebar nests them. Type to filter fuzzily by
// space, parent or machine name (match.js), ↑/↓ and Enter to go, Esc to leave. A space whose bookmark has a GitHub
// PR shows its icon before the machine (shared "space.prs", published by spaces-status). Cloned from the shipped
// `picker`, which lists tabs instead.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { spaces, run, theme, settings, props, closeOverlay, shared, setShared } from "herdr";
import { matches } from "./match.js";

const ROW_HEIGHT = { space: 32, earlier: 35 };
const LIST_MAX = 320;
const STATUS_RANK = { blocked: 0, done: 1, working: 2, idle: 3 };

const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

// A PR's icon, as the sidebar draws it (spaces-status/prs.js `prLook`): the file per state, open PRs colored by CI.
const PR_ICONS = { open: "git-pull-request.svg", draft: "git-pull-request-draft.svg", merged: "git-merge.svg", closed: "git-pull-request-closed.svg" };
function prColor(t, pr) {
  if (pr.state === "merged") return t.ansi5;
  if (pr.state !== "open") return t.dim;
  return { passing: t.ansi2, failing: t.ansi1, running: t.ansi3 }[pr.ci] ?? t.dim;
}

// Space colors, kept by space id in shared "space.colors": a theme
// color name ("ansi6") or a picked #rrggbb. A space seen without one gets
// the theme color fewest spaces use, once; every mod does the same in the
// same order, so they agree, and adding or renaming spaces moves nothing.
const PROJECT_COLORS = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];
function spaceColors() {
  const ids = new Set(spaces().map((p) => p.id));
  const kept = Object.fromEntries(Object.entries(shared("space.colors") ?? {}).filter(([id]) => ids.has(id)));
  let changed = Object.keys(kept).length !== Object.keys(shared("space.colors") ?? {}).length;
  for (const p of spaces()) {
    if (kept[p.id] || p.name === "~") continue;
    const uses = (c) => Object.values(kept).filter((v) => v === c).length;
    kept[p.id] = PROJECT_COLORS.reduce((best, c) => (uses(c) < uses(best) ? c : best));
    changed = true;
  }
  if (changed) setShared("space.colors", kept);
  return kept;
}
function spaceColor(t, p) {
  if (p.name === "~") return t.dim;
  const c = spaceColors()[p.id] ?? PROJECT_COLORS[0];
  return c.startsWith("#") ? c : (MARK[c] ?? t[c]);
}

export default class SpacePicker extends View {
  init(_props, cx) {
    this.filter = "";
    this.at = null;
    this.scroll = 0;
    this.showEarlier = false;
    this.handle = cx.focus_handle();

    this.input = InputState.new({ placeholder: "Go to a space…" });
    this.input.on("change", (_e, cx) => {
      this.filter = this.input.value();
      this.at = 0;
      cx.notify();
    });
    this.input.on("submit", (_e, cx) => this.go(this.rows()[this.at], cx));
    this.input.focus();
    // The popup can still be opening on the first focus; ask again once it's shown.
    cx.timer.after(600, () => this.input.focus());
  }

  close() {
    closeOverlay(props().overlay);
  }

  // Busy spaces, then quiet ones behind an "earlier" row; a filter shows every match unfolded.
  // Spaces never shown since recording began sort last in their group, in sidebar order (the sort is stable).
  rows() {
    const all = spaces();
    const f = this.filter.trim();
    const seen = shared("space.seen") ?? {};
    const recent = (a, b) => (seen[b.id] ?? 0) - (seen[a.id] ?? 0);

    // A worktree space's parent, as the sidebar nests it (shared "space.parents", published by spaces-status).
    const parentIds = shared("space.parents") ?? {};
    const byId = new Map(all.map((s) => [s.id, s]));
    const parentOf = (s) => byId.get(parentIds[s.id])?.name ?? null;

    const found = all.filter((s) => matches(f, [s.name, parentOf(s), machineOf(s)]));
    const busy = found.filter((s) => s.status).sort((a, b) => (STATUS_RANK[a.status] ?? 4) - (STATUS_RANK[b.status] ?? 4) || recent(a, b));
    const quiet = found.filter((s) => !s.status).sort(recent);
    const row = (space) => ({ kind: "space", space, parent: parentOf(space) });

    if (f) return [...busy, ...quiet].map(row);

    const out = busy.map(row);
    if (quiet.length) {
      out.push({ kind: "earlier", count: quiet.length });
      if (this.showEarlier) out.push(...quiet.map(row));
    }
    return out;
  }

  go(r, cx) {
    if (!r) return;
    if (r.kind === "earlier") {
      this.showEarlier = !this.showEarlier;
      this.input.focus();
      cx.notify();
      return;
    }
    this.close();
    run("space.select", { id: r.space.id });
  }

  render() {
    const t = theme();
    const rows = this.rows();

    // Opens on the first other space: the current one is where you already are.
    if (this.at === null) this.at = rows.findIndex((r) => r.kind === "space" && !r.space.active);
    this.at = Math.max(0, Math.min(this.at, rows.length - 1));
    const sel = rows[this.at];

    // One continuous strip: each row at a fixed y. Scrolling moves the strip only as far
    // as it takes to keep the selected row in view, so the arrows can't run the selection off the list.
    const tops = [];
    let y = 0;
    rows.forEach((r) => { tops.push(y); y += ROW_HEIGHT[r.kind]; });
    const total = y;
    const height = Math.min(LIST_MAX, this.listHeight ?? LIST_MAX);
    const fixed = total > height;
    const maxScroll = Math.max(0, total - height);
    const bottom = (i) => tops[i] + ROW_HEIGHT[rows[i].kind];
    this.scroll = Math.max(0, Math.min(this.scroll, maxScroll));
    if (sel) {
      if (tops[this.at] < this.scroll) this.scroll = tops[this.at];
      if (bottom(this.at) > this.scroll + height) this.scroll = bottom(this.at) - height;
    }
    const place = (el, i) => (fixed ? el.absolute().left(0).right(0).top(tops[i] - this.scroll).bottom(height - (bottom(i) - this.scroll)) : el);
    const visible = (i) => !fixed || (bottom(i) > this.scroll && tops[i] < this.scroll + height);
    const row = (r) => (r.kind === "earlier" ? this.earlierRow(t, r, r === sel) : this.spaceRow(t, r, r === sel));

    return v_flex()
      .id("goto")
      .track_focus(this.handle)
      .w_full()
      .min_h(0)
      .p(18)
      .gap(10)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "escape") return this.close();
        if (rows.length === 0) return;
        if (k === "down") this.at = (this.at + 1) % rows.length;
        else if (k === "up") this.at = (this.at + rows.length - 1) % rows.length;
        else return;
        cx.stop_propagation();
        cx.notify();
      })
      .child(h_flex().items_center().child(div().flex_1().text_size(15).font_semibold().text_color(t.foreground).child("Go to…")).child(div().id("goto-esc").px(6).py(2).rounded(5).text_size(11).text_color(t.dim).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click(() => this.close()).child("Esc")))
      .child(
        h_flex().h(36).flex_none().px(10).gap(8).items_center().rounded(9).border_1().border_color(t.accent).bg(t.background)
          .child(svg("mods/workspace-chrome/search.svg").size(15).text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
      )
      .when(rows.length === 0, (el) => el.child(div().px(10).py(8).mb(6).text_size(12).text_color(t.dim).child("No matching space")))
      .when(rows.length > 0, (el) =>
        el.child(
          v_flex()
            .id("goto-list")
            .on_size_change((size, cx) => {
              this.listHeight = size.height / settings().zoom;
              cx.notify();
            })
            .h(Math.min(LIST_MAX, total))
            .min_h(0)
            .mb(6)
            .when(fixed, (el) =>
              el.overflow_hidden().on_scroll_wheel((e, cx) => {
                this.scroll = Math.max(0, Math.min(this.scroll - e.delta.y, maxScroll));
                // The selection follows the wheel, so the next frame doesn't scroll back to it.
                while (this.at < rows.length - 1 && tops[this.at] < this.scroll) this.at++;
                while (this.at > 0 && bottom(this.at) > this.scroll + height) this.at--;
                cx.notify();
              }))
            .children(rows.map((r, i) => (visible(i) ? place(row(r), i) : null)).filter(Boolean)),
        ));
  }

  spaceRow(t, r, selected) {
    const s = r.space;
    const pr = (shared("space.prs") ?? {})[s.id];
    return h_flex()
      .id(`goto-${s.id}`)
      .mx(4)
      .px(10)
      .h(ROW_HEIGHT.space)
      .rounded(7)
      .gap(10)
      .items_center()
      .cursor_pointer()
      .when(selected, (el) => el.bg(t.hover))
      .hover((st) => st.bg(t.hover))
      .on_click((_e, cx) => this.go(r, cx))
      .child(this.glyph(t, s.status))
      .child(h_flex().size(18).flex_none().rounded(5).bg(spaceColor(t, s)).items_center().justify_center().text_size(10.5).font_bold().text_color("#ffffff").child([...s.name][0]?.toUpperCase() ?? "?"))
      .child(h_flex().flex_1().min_w(0).items_center()
        .when(Boolean(r.parent), (el) => el.child(div().flex_none().text_color(t.dim).child(`${r.parent} › `)))
        .child(div().truncate().text_color(t.foreground).when(s.active, (d) => d.font_semibold()).child(s.name)))
      .when(s.status === "blocked", (el) => el.child(div().text_size(11).text_color(t.blocked).child("needs you")))
      .when(s.status === "done", (el) => el.child(div().text_size(11).text_color(t.done).child("finished")))
      .when(Boolean(pr), (el) => el.child(svg(`mods/spaces-status/${PR_ICONS[pr.state] ?? PR_ICONS.open}`).size(12).flex_none().text_color(prColor(t, pr))))
      .child(div().text_size(11).text_color(t.dim).child(machineOf(s)));
  }

  earlierRow(t, r, selected) {
    return h_flex()
      .id("goto-earlier")
      .mt(6)
      .px(10)
      .py(6)
      .border_t(1)
      .border_color(t.border)
      .text_size(12)
      .text_color(t.dim)
      .cursor_pointer()
      .when(selected, (el) => el.bg(t.hover).text_color(t.foreground))
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => this.go(r, cx))
      .child(`earlier: ${r.count} quiet space${r.count > 1 ? "s" : ""} ${this.showEarlier ? "▴" : "▾"}`);
  }

  glyph(t, st) {
    if (st === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900);
    return div().w(12).flex_none().text_color(t[st] ?? t.dim).child(st === "idle" ? "○" : st ? "●" : "·");
  }
}

// herdr leaves `machine` unset for spaces on this computer.
function machineOf(space) {
  return space.machine ?? "local";
}
