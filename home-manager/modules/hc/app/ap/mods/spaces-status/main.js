// Workspace spaces: stable colored avatars, worktrees under their checkout,
// grouped by machine when more than one is known. At a row's end, the GitHub PR of
// the jj bookmark its first terminal is on (shape for its state, color for its CI;
// a click opens it) and the space's most urgent agent status. Click to switch,
// right-click for its menu, drag to reorder.

import * as fs from "fs/promises";
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, machines, panes, terminals, run, nextCommand, openOverlay, exec, hc, theme, shared, setShared, watchFolder, window, layout, home, appHome } from "herdr";
import { CAP, parseGh, prSummary, ciRollup, nextDue, prLook, prTip, hasCi } from "./prs.js";
import { groupRows } from "./rows.js";
import { readMachineOrder, resolveMachineOrder, moveMachine, trackMachinePress, releaseMachinePress } from "./machine-order.js";
import { visibleNavOrder, step } from "./nav.js";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// Where a space is now: its first terminal's live folder, else where it was made.
// `ps`: panes(), read once by the caller (each read copies every pane).
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
const rowHeight = ({ tree }) => (tree ? 28 : 30);
const machineKey = m => m === null ? "local" : `remote:${m}`;
const where = (s, ps) => JSON.stringify([s.machine ?? null, place(s, ps)]);
const base = (path) => path.replace(/\/+$/, "").split("/").pop();
// Changes made outside Herdr (an editor's save, a commit in another app): looked
// for this often, in repos the list shows, while the window is in front.
const FALLBACK = 60000;
// This mod's folder, for its own icons (`svg()` paths start at the app's folder).
const SELF = "spaces-status";
const HOUR = 3600000;
// Without a working gh, how long until asking again whether there is one.
const GH_RECHECK = 30 * 60000;
const GH_LOG = () => `${appHome()}/data/${SELF}/github.log`;

// What a stored color name looks like on an avatar (the same in every mod
// that draws space avatars): one strong color per hue, light and dark alike.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

// A space speaks up only when something in it needs you.
export function glyph(status) {
  return status === "blocked" || status === "done" ? "●" : "·";
}

export function tone(t, status) {
  return t[status] ?? t.unknown;
}

export default class Spaces extends View {
  init(_props, cx) {
    this.git = {}; // where() -> { name, branch, repo, linked }, null: not a repo
    this.jj = {}; // repo -> its bookmark, null: not a jj repo, never asked again
    this.checked = {}; // where() -> when it was last looked at
    this.unsure = new Set(); // where()s git couldn't answer for (a machine away)
    this.pending = new Set(); // where()s to look at next
    this.busy = {}; // pane -> an agent working or a program in front of its shell
    this.ready = {}; // machine -> its layout was readable at the last look
    this.at = {}; // space -> its where() at the last look
    this.watching = new Set(); // local repos' git folders
    // GitHub PRs (see prs.js). gh runs here only, also for other machines' spaces:
    // a PR depends on the repo and bookmark, not on where the checkout is.
    this.gh = undefined; // gh's command once found, null: none or not logged in
    this.ghAt = 0; // when gh was last looked for
    this.slugs = {}; // repo -> "owner/name" on github.com, null: not GitHub
    this.trunk = {}; // repo -> its trunk's bookmark names
    this.prOf = {}; // where() -> "owner/name#bookmark", null: no PR possible there
    this.prs = {}; // "owner/name#bookmark" -> what GitHub said and when to ask again
    this.calls = []; // when each rate-limited GitHub call was made, the last hour's
    this.tally = { counted: 0, free: 0, since: Date.now() }; // for the hourly log line
    this.remaining = null; // GitHub's last x-ratelimit-remaining
    this.asking = false;
    // Spaces made while this runs wait (at most a moment) for their git, so a
    // worktree appears under its repo instead of jumping there.
    this.shown = new Set(spaces().map((s) => s.id));
    this.born = {};
    this.pressed = null;
    this.over = null;
    this.machines = [];
    this.folded = new Set(JSON.parse(localStorage.getItem("machines.folded") ?? "[]"));
    this.machineOrder = readMachineOrder(localStorage.getItem("machines.order"));
    this.machinePress = null;
    this.repoFolded = new Set(JSON.parse(localStorage.getItem("spaces.folded") ?? "[]")); // repos whose worktree rows are hidden, keyed like g.repo (machine-scoped)
    // The active space at the last look: a folded repo opens on a change into it, never while it already holds the active space.
    this.lastActive = spaces().find((s) => s.active)?.id ?? null;
    this.navOrder = []; // ids of the rows the sidebar draws, in draw order
    this.parents = {}; // worktree space id -> main space id
    this.refreshMachines(cx);
    cx.timer.every(15000, cx => this.refreshMachines(cx));
    // `git status` walks the whole tree, on another machine a process there:
    // only when its answer could have changed (see `due`).
    cx.timer.every(250, (cx) => this.checkNew(cx));
    cx.timer.every(5000, (cx) => this.pollPrs(cx));
    this.startNav(cx);
  }

  // Step through the sidebar's visible rows on "next" / "prev" key commands.
  startNav(cx) {
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        const cmd = String(c).split(/[.:]/).pop();
        if (cmd === "next") this.stepInto(1);
        else if (cmd === "prev") this.stepInto(-1);
        cx.notify();
      }
    });
  }

  // Cycle from the active space into the next visible row. Hidden spaces anchor
  // on their group's main row (or no-op) since they are not in the order.
  stepInto(direction) {
    const active = spaces().find((space) => space.active);
    if (!active) return;
    const target = step(this.navOrder, active.id, direction, this.parents?.[active.id]);
    if (target) run("space.select", { id: target });
  }

  checkNew(cx) {
    const now = Date.now();
    const sp = spaces();
    for (const s of sp) if (!this.shown.has(s.id)) this.born[s.id] ??= now;
    const due = this.due(now, sp, panes());
    if (due.size) this.refreshGit(due, cx);
    if (sp.some((s) => !this.shown.has(s.id))) cx.notify();
  }

  // Places whose git could have changed: new ones (a new space, a cd), where a
  // command or an agent's turn just ended (a checkout, a commit, edits), those on
  // a machine that is back, and repos in view whose fallback is due.
  due(now, sp, ps) {
    // Moved there: what it knew of that place may be old.
    const at = {};
    for (const s of sp) at[s.id] = where(s, ps);
    const keys = new Set(Object.values(at).filter((k) => JSON.parse(k)[1]));
    const due = new Set([...keys].filter((k) => !(k in this.git)));
    for (const [id, k] of Object.entries(at)) if (this.at[id] && this.at[id] !== k && keys.has(k)) due.add(k);
    this.at = at;
    const spaceOf = {};
    for (const s of sp) for (const t of s.tabs ?? []) spaceOf[t.id] = s;
    const busy = {};
    for (const p of ps) {
      if (!p.terminal || !spaceOf[p.tab]) continue;
      busy[p.pane] = p.status === "working" || !(p.program?.shell || p.program?.agent);
      if (this.busy[p.pane] && !busy[p.pane]) this.sameRepo(at[spaceOf[p.tab].id], keys).forEach((k) => due.add(k));
    }
    this.busy = busy;
    for (const m of machines()) {
      const ready = m.layout === "ready";
      if (ready && this.ready[m.name] === false) for (const k of keys) if (JSON.parse(k)[0] === m.name) due.add(k);
      this.ready[m.name] = ready;
    }
    if (window().active) {
      for (const k of keys) {
        const asks = this.git[k] || this.unsure.has(k);
        if (asks && !this.folded.has(JSON.parse(k)[0]) && now - (this.checked[k] ?? 0) > FALLBACK) due.add(k);
      }
    }
    return due;
  }

  // `key` and the other places in its repo (a commit there can retarget their branch).
  sameRepo(key, keys) {
    const repo = this.git[key]?.repo;
    return [key, ...(repo ? [...keys].filter((k) => this.git[k]?.repo === repo) : [])];
  }

  refreshMachines(cx) {
    cx.spawn(async cx => {
      try { const r = await hc(["machine", "ls", "--json"]); if (r.code === 0) this.machines = (JSON.parse(r.stdout).machines ?? []).filter((m) => !m.temporary); } catch {}
      cx.notify();
    });
  }

  // One look at a time, each place once however often it was asked for meanwhile.
  refreshGit(keys, cx) {
    for (const k of keys) this.pending.add(k);
    if (this.refreshing) return;
    this.refreshing = true;
    cx.spawn(async (cx) => {
      while (this.pending.size) {
        const keys = [...this.pending];
        this.pending.clear();
        for (const key of keys) await this.check(key, cx);
      }
      const used = new Set(Object.values(this.git).filter(Boolean).map((g) => JSON.parse(g.repo)).filter(([on]) => !on).map(([, repo]) => repo));
      for (const repo of this.watching) if (!used.has(repo)) this.watching.delete(repo);
      this.refreshing = false;
      cx.notify();
    });
  }

  // One place's git: its branch and repo. A jj repo's branch is its bookmark.
  async check(key, cx) {
    const [on, cwd] = JSON.parse(key);
    this.checked[key] = Date.now();
    this.unsure.delete(key);
    try {
      // No optional locks: a status that touched the index would wake the watch again.
      // Writes nothing under .git (index lock, fsmonitor cookie): watch() would wake on it.
      const r = await exec("git", ["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch"], { cwd, on });
      if (r.code !== 0) {
        // Only git's own "no" is remembered as no repo; anything else is asked again.
        if (!/not a git repository/i.test(r.stderr)) this.unsure.add(key);
        this.git[key] = null;
        return;
      }
      // The repo's own .git folder names it; a worktree's top differs from it.
      const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
      const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, on });
      const repo = common.stdout.trim();
      const name = repo.endsWith("/.git") ? base(repo.slice(0, -5)) : base(repo).replace(/\.git$/, "");
      const info = { name, branch: null, repo: JSON.stringify([on, repo]), linked: repo !== `${top.stdout.trim()}/.git` };
      for (const line of r.stdout.split("\n")) {
        if (line.startsWith("# branch.head ")) info.branch = line.slice(14);
      }
      // A colocated jj repo leaves git on a detached HEAD: its bookmark names the work.
      if (info.branch === "(detached)") info.branch = await this.bookmark(cwd, on, repo);
      this.git[key] = info;
      if (!on) this.watch(repo, cx);
      await this.track(key, info, cwd, on, repo);
    } catch {
      // Couldn't ask (the machine is away): keep what it showed, look again later.
      this.git[key] ??= null;
      this.unsure.add(key);
    }
  }

  // The jj bookmark at the working-copy commit, or "" when it has none. Asked per
  // place, cached per repo: null marks a repo that isn't jj, asked once and no more.
  async bookmark(cwd, on, repo) {
    if (this.jj[repo] === null) return null;
    // Not snapshotting: that writes the working copy and would wake watch().
    const r = await exec("jj", ["--ignore-working-copy", "log", "--no-graph", "-r", "closest_bookmark(@)",
      "-T", 'local_bookmarks.map(|b| b.name()).join(",")'], { cwd, on });
    this.jj[repo] = r.code === 0 ? r.stdout.trim() : null;
    return this.jj[repo];
  }

  // Which PR a place's bookmark could have ("owner/name#bookmark"), and its pushed
  // commit: a new one (or a new bookmark) is when GitHub is asked first. No PR is
  // possible off jj, off GitHub, or on trunk's own bookmark.
  async track(key, info, cwd, on, repo) {
    const name = this.jj[repo] ? (info.branch ?? "").split(",")[0] : "";
    const slug = name ? await this.slug(info.repo, cwd, on) : null;
    if (!slug || (await this.trunkNames(info.repo, cwd, on)).includes(name)) {
      this.prOf[key] = null;
      return;
    }

    const r = await exec("jj", ["--ignore-working-copy", "log", "--no-graph", "-r",
      `remote_bookmarks(exact:${JSON.stringify(name)}, exact:"origin")`, "-T", 'commit_id ++ "\\n"'], { cwd, on });
    if (r.code !== 0) return;
    const pushed = r.stdout.trim().split("\n")[0] || null;

    const k = `${slug}#${name}`;
    this.prOf[key] = k;
    const e = (this.prs[k] ??= { slug, bookmark: name, at: 0, errors: 0, pr: null, ci: "none", etags: {} });
    // Seen first, or pushed anew: ask now (an unpushed bookmark once, for a PR whose
    // branch GitHub deleted after the merge).
    if (!("pushed" in e) || e.pushed !== pushed) Object.assign(e, { since: Date.now(), due: Date.now(), urgent: true, errors: 0 });
    e.pushed = pushed;
  }

  // The repo's GitHub "owner/name" from its origin remote, asked once per repo.
  async slug(repo, cwd, on) {
    if (repo in this.slugs) return this.slugs[repo];
    const r = await exec("git", ["remote", "get-url", "origin"], { cwd, on });
    const m = /github\.com[:/]([^/\s]+)\/([^/\s]+?)(?:\.git)?\/?$/.exec(r.stdout.trim());
    this.slugs[repo] = r.code === 0 && m ? `${m[1]}/${m[2]}` : null;
    return this.slugs[repo];
  }

  // The bookmarks on the repo's trunk (master, main): a workspace with no bookmark of
  // its own resolves to them, and their PRs aren't the space's.
  async trunkNames(repo, cwd, on) {
    if (this.trunk[repo]) return this.trunk[repo];
    const r = await exec("jj", ["--ignore-working-copy", "log", "--no-graph", "-r", "trunk()",
      "-T", 'bookmarks.map(|b| b.name()).join(",")'], { cwd, on });
    if (r.code !== 0) return [];
    this.trunk[repo] = [...new Set(r.stdout.trim().split(",").filter(Boolean))];
    return this.trunk[repo];
  }

  watch(repo, cx) {
    if (this.watching.has(repo)) return;
    this.watching.add(repo);
    cx.spawn(async (cx) => {
      try {
        while (this.watching.has(repo)) {
          await watchFolder(repo);
          const mine = JSON.stringify([null, repo]);
          if (this.watching.has(repo)) this.refreshGit(Object.keys(this.git).filter((k) => this.git[k]?.repo === mine), cx);
        }
      } catch { this.watching.delete(repo); }
    });
  }

  // GitHub, one question at a time: the most overdue PR, a fresh push first. Timed
  // checks only while the window is in front, all of them within the hourly cap.
  pollPrs(cx) {
    if (this.asking) return;
    const now = Date.now();
    if (this.gh === undefined || (this.gh === null && now - this.ghAt > GH_RECHECK)) return this.findGh(cx);
    if (!this.gh) return;

    this.logTally(now);
    this.calls = this.calls.filter((c) => now - c < HOUR);
    if (this.calls.length >= CAP) return;

    const active = window().active;
    const next = [...new Set(Object.values(this.prOf).filter(Boolean))]
      .map((k) => this.prs[k])
      .filter((e) => e?.due && e.due <= now && (e.urgent || active))
      .sort((a, b) => b.urgent - a.urgent || a.due - b.due)[0];
    if (!next) return;

    this.asking = true;
    cx.spawn(async (cx) => {
      try {
        await this.ask(next);
      } finally {
        this.asking = false;
      }
      cx.notify();
    });
  }

  // gh on PATH, else the user's nix profile; logged in to github.com or it doesn't count.
  findGh(cx) {
    this.asking = true;
    cx.spawn(async (cx) => {
      const had = this.gh;
      this.gh = null;
      for (const cmd of ["gh", `${home()}/.nix-profile/bin/gh`]) {
        try {
          if ((await exec(cmd, ["auth", "status", "--hostname", "github.com"])).code === 0) {
            this.gh = cmd;
            break;
          }
        } catch {}
      }
      this.ghAt = Date.now();
      if (!this.gh && had !== null) await this.note("gh missing or not logged in to github.com: no PR icons; looking again every 30 min");
      this.asking = false;
      cx.notify();
    });
  }

  // One repo + bookmark: its newest PR, then the CI of that PR's head commit while it's
  // open. Each request carries the last answer's ETag, so an unchanged one is free.
  async ask(e) {
    const now = Date.now();
    e.urgent = false;
    const owner = e.slug.split("/")[0];
    const pulls = await this.api(`repos/${e.slug}/pulls?head=${owner}:${encodeURIComponent(e.bookmark)}&state=all&per_page=1`, e, "pulls");
    let ok = pulls.status === 200 || pulls.status === 304;
    if (pulls.status === 200) e.pr = prSummary(pulls.body);

    if (ok && hasCi(e.pr)) {
      // A new head commit has new checks: the old ETag would answer for the old one.
      if (e.etags.checksFor !== e.pr.headSha) {
        delete e.etags.checks;
        e.etags.checksFor = e.pr.headSha;
      }
      const checks = await this.api(`repos/${e.slug}/commits/${e.pr.headSha}/check-runs?per_page=100`, e, "checks");
      if (checks.status === 200) e.ci = ciRollup(checks.body);
      ok = checks.status === 200 || checks.status === 304;
    }

    e.errors = ok ? 0 : e.errors + 1;
    e.at = now;
    e.remaining = this.remaining;
    e.due = nextDue(e);
  }

  // `gh api -i`, conditional when an ETag is known; counts what the rate limit counts.
  async api(path, e, slot) {
    const args = ["api", "-i", path];
    if (e.etags[slot]) args.push("-H", `If-None-Match: ${e.etags[slot]}`);
    let r;
    try {
      r = parseGh(await exec(this.gh, args, { timeout: 20000 }));
    } catch {
      r = parseGh(null);
    }

    if (r.status === 304) this.tally.free++;
    else if (r.status !== "error") {
      this.calls.push(Date.now());
      this.tally.counted++;
    }
    if (r.status === 200 && r.etag) e.etags[slot] = r.etag;
    if (r.remaining !== null) this.remaining = r.remaining;
    e.pollInterval = r.pollInterval;
    return r;
  }

  // Once an hour with any GitHub traffic: how much of it the rate limit counted.
  logTally(now) {
    const { counted, free, since } = this.tally;
    if (now - since < HOUR) return;
    this.tally = { counted: 0, free: 0, since: now };
    if (counted || free) this.note(`GitHub calls in the last hour: ${counted} counted, ${free} unchanged (304, free); ${this.remaining ?? "?"} left`);
  }

  // A line for the person, in data/spaces-status/github.log (its last 200 lines kept).
  async note(line) {
    console.log(`${SELF}: ${line}`);
    try {
      const path = GH_LOG();
      await fs.mkdir(path.slice(0, path.lastIndexOf("/")), { recursive: true });
      let old = "";
      try {
        old = await fs.readFile(path, "utf8");
      } catch {}
      const lines = [...old.split("\n").filter(Boolean), `${new Date().toISOString()} ${line}`].slice(-200);
      await fs.writeFile(path, `${lines.join("\n")}\n`);
    } catch {}
  }

  menu(w) {
    // A popup is as tall as its items; height is only the most.
    openOverlay({ mod: "menu", kind: "popup", width: 200, height: 260, props: { tab: "space", target: { id: w.id } } });
  }

  // Spaces in order, each worktree space moved under its main checkout's.
  ordered() {
    const sp = spaces(), ps = panes();
    const ready = (w) => this.shown.has(w.id) || where(w, ps) in this.git || Date.now() - (this.born[w.id] ??= Date.now()) > 1500;
    for (const w of sp) if (!this.shown.has(w.id) && ready(w)) this.shown.add(w.id);
    const list = sp.map((w, i) => ({ w, i, g: this.git[where(w, ps)] ?? null })).filter((r) => this.shown.has(r.w.id));
    // A jump into a worktree of a folded repo opens it, but only on a change of
    // active space: folding the group you're in sticks while you remain there.
    const active = sp.find((s) => s.active);
    if (active && active.id !== this.lastActive) {
      const g = this.git[where(active, ps)];
      if (g?.linked && this.repoFolded.has(g.repo)) {
        this.repoFolded.delete(g.repo);
        localStorage.setItem("spaces.folded", JSON.stringify([...this.repoFolded]));
      }
    }
    this.lastActive = active?.id ?? null;
    const { rows, parents } = groupRows(list, this.repoFolded);
    this.parents = parents;
    this.publishParents(parents);
    this.publishPrs(sp, ps);
    return rows;
  }

  // Shared "space.parents", read by the `goto` picker to show and match each worktree's parent. Called from
  // render, so it writes only when the nesting changed, keeping the write from re-rendering in a loop.
  publishParents(parents) {
    if (JSON.stringify(shared("space.parents") ?? {}) !== JSON.stringify(parents)) setShared("space.parents", parents);
  }

  // Shared "space.prs" (space id -> its PR), drawn by this list and the `goto` picker. Until GitHub has answered
  // for a place, its last published PR stays, so icons show right after a restart. Written only on change.
  publishPrs(sp, ps) {
    const prev = shared("space.prs") ?? {};
    const next = {};
    if (this.gh !== null) {
      for (const s of sp) {
        const k = this.prOf[where(s, ps)];
        const e = k ? this.prs[k] : null;
        const old = prev[s.id];
        if (e?.at && e.pr) next[s.id] = summary(e);
        else if (old && (k === undefined || (e && !e.at && `${old.repo}#${old.bookmark}` === k))) next[s.id] = old;
      }
    }
    if (JSON.stringify(prev) !== JSON.stringify(next)) setShared("space.prs", next);
  }

  // The rows, under a header per machine once one isn't this computer.
  grouped(t, collapsed) {
    const rows = this.ordered();
    const draw = (r) => (collapsed ? this.compact(r, t) : this.row(r, t));
    const remote = [...rows.map(r => r.w.machine).filter(Boolean), ...this.machines.map(m => m.name)];
    const order = resolveMachineOrder(this.machineOrder, remote);
    if (collapsed || !remote.length || (this.machinePress && !order.visible.includes(this.machinePress.source))) {
      this.cancelMachinePress();
    }

    const loading = m => {
      const layout = machines().find(k => k.name === m)?.layout;
      return layout === "loading" || (!layout && this.machines.some(k => k.name === m && k.state === "connected"))
        || spaces().some(s => (s.machine ?? null) === m && !this.shown.has(s.id));
    };
    const loadingRow = m => div().id(`machine-loading-${machineKey(m)}`).h(28).flex_none().px(8).text_size(12).text_color(t.dim).child(collapsed ? "…" : "Loading…");
    if (!remote.length) {
      this.navOrder = rows.filter((r) => !r.hidden).map((r) => r.w.id);
      return loading(null) && !rows.length ? [loadingRow(null)] : rows.filter((r) => !r.hidden).map(draw);
    }

    const sections = order.visible.map((m) => ({
      machine: m,
      rows: rows.filter((r) => (r.w.machine ?? null) === m),
    }));
    this.navOrder = visibleNavOrder(sections, this.folded);

    return order.visible.flatMap((m) => {
      const sectionRows = rows.filter((r) => (r.w.machine ?? null) === m);
      const mine = sectionRows.filter((r) => !r.hidden);
      const head = this.machineHeader(m, order, t, collapsed, sectionRows.length);
      const empty = h_flex().id(`machine-new-${machineKey(m)}`).h(28).flex_none().px(8).gap(7).items_center().rounded(7)
        .text_size(12).text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => run("space.new", m ? { machine: m } : {}))
        .child(svg("mods/workspace-chrome/plus.svg").size(12)).when(!collapsed, el => el.child("New space there"));
      return [head, ...(this.folded.has(m) ? [] : mine.length ? mine.map(draw) : [loading(m) ? loadingRow(m) : empty])];
    });
  }

  machineHeader(m, order, t, collapsed, count = 0) {
    const machine = this.machines.find(k => k.name === m);
    const connected = m === null || machine?.state === "connected";
    const folded = this.folded.has(m);
    const key = machineKey(m);
    const press = this.machinePress;
    const over = press?.over === m;
    const before = over && order.visible.indexOf(press.source) > order.visible.indexOf(m);

    return h_flex().id(`machine-${key}`).relative().h(26).flex_none().px(collapsed ? 2 : 8).gap(7).items_center().text_size(11).text_color(t.dim)
      .cursor_pointer().hover(s => s.bg(t.hover))
      .when(collapsed, el => el.on_click((_e, cx) => this.toggleMachineFold(m, cx)))
      .when(!collapsed, el => el
        .on_mouse_down("left", (e, cx) => {
          cx.stop_propagation();
          this.cancelMachinePress(cx);
          this.machinePress = { source: m, y: e.position.y, dragging: false, over: undefined };
        })
        // The viewport treats moves that reach it as being outside a machine header.
        .on_mouse_move((e, cx) => {
          if (!this.machinePress) return;
          cx.stop_propagation();
          this.previewMachinePress(m, e.position.y, cx);
        })
        .on_mouse_up("left", (e, cx) => this.finishMachinePress(m, order, e.position.y, cx)))
      .child(svg(`mods/workspace-chrome/${m ? "server" : "monitor"}.svg`).size(13).flex_none())
      .when(!collapsed, el => el.child(div().flex_1().truncate().child(m ?? "This computer"))
        .when(folded && count > 0, el => el.child(div().flex_none().text_size(11).text_color(t.dim).child(String(count))))
        .when(!connected, el => el.child(div().flex_none().child((machine?.state ?? "asleep").replace(/_/g, " "))))
        .when(connected, el => el.child(div().id(`machine-add-${key}`).flex_none().px(4).rounded(4).hover(s => s.bg(t.hover).text_color(t.foreground))
          .on_mouse_down("left", (_e, cx) => { cx.stop_propagation(); this.cancelMachinePress(cx); })
          .on_mouse_move((e, cx) => {
            if (!this.machinePress) return;
            cx.stop_propagation();
            this.previewMachinePress(undefined, e.position.y, cx);
          })
          .on_mouse_up("left", (_e, cx) => this.cancelMachinePress(cx))
          .on_click((_e, cx) => { cx.stop_propagation(); run("space.new", m ? { machine: m } : {}); }).child("+")))
        .child(div().size(6).rounded(3).flex_none().bg(connected ? t.ansi2 : t.dim))
        .child(svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`).size(11).flex_none()))
      .when(over, el => el.child(div().absolute().left(0).right(0).h(2).bg(t.accent)
        .when(before, line => line.top(0))
        .when(!before, line => line.bottom(0))));
  }

  toggleMachineFold(m, cx) {
    this.folded.has(m) ? this.folded.delete(m) : this.folded.add(m);
    localStorage.setItem("machines.folded", JSON.stringify([...this.folded]));
    cx.notify();
  }

  previewMachinePress(target, y, cx) {
    const press = this.machinePress;
    if (!press) return;
    this.machinePress = trackMachinePress(press, target, y);
    if (this.machinePress !== press) cx.notify();
  }

  finishMachinePress(target, order, y, cx) {
    const press = this.machinePress;
    if (!press) return;
    this.machinePress = null;

    const action = releaseMachinePress(press, target, y);
    if (action === "fold") return this.toggleMachineFold(target, cx);
    if (action === "move") {
      const next = moveMachine(order, press.source, target);
      if (next) {
        this.machineOrder = next;
        localStorage.setItem("machines.order", JSON.stringify(next));
      }
    }
    cx.notify();
  }

  cancelMachinePress(cx) {
    if (!this.machinePress) return;
    this.machinePress = null;
    cx?.notify();
  }

  // The PR of the space's bookmark: shape for its state, color for its CI. A click opens it in the
  // browser; the press stops here, so the row neither switches space nor starts a drag.
  prIcon(w, pr, t) {
    const { icon, color } = prLook(pr, t);
    return div()
      .id(`pr-${w.id}`)
      .flex_none()
      .p(2)
      .rounded(4)
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .tooltip(prTip(pr))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => {
        cx.stop_propagation();
        exec("open", [pr.url]).catch(() => {});
      })
      .child(svg(`mods/${SELF}/${icon}`).size(12).text_color(color));
  }

  // Click opens the space's workspace URL in the browser.
  // Fold/unfold a repo's worktree rows. Its own press target, like the PR and URL icons: the row
  // keeps switching spaces on a click everywhere else.
  foldChevron(w, g, t) {
    const repo = g.repo;
    const folded = this.repoFolded.has(repo);
    return div()
      .id(`fold-${w.id}`)
      .flex_none()
      .p(2)
      .rounded(4)
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => {
        cx.stop_propagation();
        folded ? this.repoFolded.delete(repo) : this.repoFolded.add(repo);
        localStorage.setItem("spaces.folded", JSON.stringify([...this.repoFolded]));
        cx.notify();
      })
      .child(svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`).size(11).flex_none().text_color(t.dim));
  }

  // Click opens the space's workspace URL in the browser.
  urlIcon(w, url, t) {
    return div()
      .id(`url-${w.id}`)
      .flex_none()
      .p(2)
      .rounded(4)
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .tooltip(url)
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => {
        cx.stop_propagation();
        exec("open", [url]).catch(() => {});
      })
      .child(svg(`mods/${SELF}/globe.svg`).size(12).text_color(t.accent));
  }

  // Click opens the space's show-me server in the browser; right-click clears stale labels.
  showMeIcon(w, entries, t) {
    return div()
      .id(`show-me-${w.id}`)
      .flex_none()
      .p(2)
      .rounded(4)
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .tooltip(showMeTip(entries))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => {
        cx.stop_propagation();
        exec("open", [entries[0].url]).catch(() => {});
      })
      .on_mouse_down("right", (_e, cx) => {
        cx.stop_propagation();
        clearShowMe(entries);
      })
      .child(svg("mods/workspace-chrome/monitor.svg").size(12).text_color(t.accent));
  }

  // The space's most urgent agent status, in the agents list's shapes: a spinner
  // while it works, filled for blocked and done, a hollow ring for idle.
  statusDot(status, t) {
    if (status === "working") return svg("mods/workspace-chrome/spinner.svg").size(11).flex_none().text_color(tone(t, "working")).spin(900);
    if (status === "idle") return div().size(7).mx(2).flex_none().rounded(4).border(1.5).border_color(tone(t, "idle"));
    return div().size(7).mx(2).flex_none().rounded(4).bg(tone(t, status));
  }

  row({ w, i, g, tree, kids }, t) {
    const on = w.active;
    const pr = (shared("space.prs") ?? {})[w.id];
    const showMe = spaceShowMe(w.id);
    const url = spaceUrl(w.id);
    const colors = shared("space.colors") ?? {};
    const color = colors[w.id] ?? "ansi6";
    const fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
    return v_flex()
      .relative()
      .id(`space-${w.id}`)
      .px(8)
      .h(rowHeight({ tree }))
      .flex_none()
      .justify_center()
      .rounded(8)
      .when(on, (el) => el.bg(t.selected))
      .when(!on, (el) => el.hover((s) => s.bg(t.hover)))
      .when(this.pressed === i && this.over !== i, (el) => el.opacity(0.5))
      .when(this.pressed !== null && this.over === i && this.pressed !== i, (el) => el.child(
        div().absolute().left(0).right(0).h(2).bg(t.accent)
          .when(this.pressed < i, line => line.bottom(0))
          .when(this.pressed > i, line => line.top(0)),
      ))
      .on_mouse_down("left", () => {
        this.pressed = i;
        this.over = i;
      })
      .on_mouse_move((_e, cx) => {
        const source = spaces()[this.pressed];
        const over = source && (source.machine ?? null) === (w.machine ?? null) ? i : null;
        if (this.pressed !== null && this.over !== over) {
          this.over = over;
          cx.notify();
        }
      })
      .on_mouse_up("left", (_e, cx) => {
        const from = this.pressed;
        const over = this.over;
        this.pressed = null;
        this.over = null;
        if (from !== null && over === i && from !== i) run("space.move", { id: spaces()[from].id, index: i + 1 });
        else if (from === i) run("space.select", { id: w.id });
        cx.notify();
      })
      .on_mouse_down("right", () => this.menu(w))
      .child(
        h_flex()
          .gap(9)
          .items_center()
          .when(Boolean(tree), el => el.pl(22).child(svg("mods/workspace-chrome/branch.svg").size(13).text_color(t.dim)))
          .when(!tree, el => el.child(h_flex().size(18).flex_none().rounded(5).bg(fill).items_center().justify_center().text_size(10.5).font_bold().text_color("#ffffff").child([...w.name][0]?.toUpperCase() ?? "?")))
          .child(div().flex_shrink(0).max_w(150).truncate().text_color(t.foreground).child(w.name))
          .when(kids > 0 && this.repoFolded.has(g.repo), (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(String(kids))))
          .child(div().flex_1())
          .when(Boolean(url), (el) => el.child(this.urlIcon(w, url, t)))
          .when(showMe.length > 0, (el) => el.child(this.showMeIcon(w, showMe, t)))
          .when(Boolean(pr), (el) => el.child(this.prIcon(w, pr, t)))
          .when(Boolean(w.status), (el) => el.child(this.statusDot(w.status, t)))
          .when(kids > 0, (el) => el.child(this.foldChevron(w, g, t))),
      );
  }

  compact({ w, i }, t) {
    return h_flex()
      .id(`space-${w.id}`)
      .h(26)
      .flex_none()
      .justify_center()
      .gap(4)
      .when(w.active, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.hover))
      .on_click(() => run("space.select", { id: w.id }))
      .child(div().text_color(w.active ? t.foreground : t.muted).child(String(i + 1)))
      .child(div().text_color(tone(t, w.status)).child(glyph(w.status)));
  }

  render() {
    const t = theme();
    const collapsed = narrow();
    const palette = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];
    const sp = spaces();
    const ids = new Set(sp.map(p => p.id));
    const kept = Object.fromEntries(Object.entries(shared("space.colors") ?? {}).filter(([id]) => ids.has(id)));
    let changed = Object.keys(kept).length !== Object.keys(shared("space.colors") ?? {}).length;
    for (const p of sp) {
      if (kept[p.id] || p.name === "~") continue;
      const uses = c => Object.values(kept).filter(v => v === c).length;
      kept[p.id] = palette.reduce((best, c) => uses(c) < uses(best) ? c : best);
      changed = true;
    }
    if (changed) setShared("space.colors", kept);
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(h_flex().h(31).pl(16).pr(10).items_center().justify_between().text_size(11.5).text_color(t.dim)
        .when(!collapsed, el => el.child("Spaces"))
        .child(div().id("space-new").size(26).flex_none().flex().items_center().justify_center().rounded(6).hover(s => s.bg(t.hover).text_color(t.foreground))
          .on_click(() => run("space.new")).child(svg("mods/workspace-chrome/plus.svg").size(14))))
      .child(v_flex().id("spaces-scroll").flex_1().min_h(0).px(8).pb(14).overflow_y_scrollbar().mode("always")
        .when(!collapsed, el => el
          .on_hover((hovered, cx) => { if (!hovered) this.cancelMachinePress(cx); })
          .on_mouse_down("left", (_e, cx) => this.cancelMachinePress(cx))
          .on_mouse_down_out((_e, cx) => this.cancelMachinePress(cx))
          .on_mouse_move((e, cx) => this.previewMachinePress(undefined, e.position.y, cx)))
        .on_mouse_up("left", (_e, cx) => {
          this.cancelMachinePress();
          this.pressed = null;
          cx.notify();
        })
        .children(this.grouped(t, collapsed)));
  }
}

// A `space.prs` entry: what the icon and its tooltip need. CI only counts on open and draft PRs.
function summary(e) {
  const { number, title, url, state } = e.pr;
  return { number, title, url, state, ci: hasCi(e.pr) ? e.ci : "none", repo: e.slug, bookmark: e.bookmark };
}

// Live labelled terminals belonging to a space.
// Remote terminals omit the `machine/` prefix in `herdr.space`, so restore it from `address`.
function spaceTerminals(spaceId) {
  return terminals().filter((term) => {
    if (term.state !== "live" || !term.labels) return false;
    const raw = term.labels["herdr.space"];
    if (!raw) return false;
    const slash = term.address.indexOf("/");
    const full = slash >= 0 ? `${term.address.slice(0, slash + 1)}${raw}` : raw;
    return full === spaceId;
  });
}

// The space's workspace URL: the first `space.url` label, set by AP's fish hook from the
// workspace's environment (hc/space-url.fish).
function spaceUrl(spaceId) {
  return spaceTerminals(spaceId).map((term) => term.labels["space.url"]).find(Boolean) ?? null;
}

// Live `show-me.<port>=<url>` labels belonging to a space, highest port first.
function spaceShowMe(spaceId) {
  const out = [];
  for (const term of spaceTerminals(spaceId)) {
    for (const [key, url] of Object.entries(term.labels)) {
      if (key.startsWith("show-me.") && url) {
        out.push({ address: term.address, key, port: Number(key.slice(8)) || 0, url });
      }
    }
  }
  return out.sort((a, b) => b.port - a.port);
}

function clearShowMe(entries) {
  return Promise.all(entries.map(({ address, key }) => hc(["label", address, `${key}=`]).catch(() => {})));
}

function showMeTip(entries) {
  const urls = entries.map((e) => e.url).join("\n");
  return entries.length > 1
    ? `Show-me (${entries.length})\n${urls}\nRight-click to clear`
    : `Show-me · ${urls}\nRight-click to clear`;
}
