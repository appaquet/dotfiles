// A space's GitHub PR: its state and CI read from `gh api -i` answers, and when to
// ask GitHub again. Pure (no herdr imports), so plain `node` can exercise it.

// Rate-limited GitHub calls allowed per hour, and the remaining count under which
// timed checks slow down.
export const CAP = 200;
export const LOW = 500;

const SEC = 1000;
const MIN = 60 * SEC;

// After a bookmark or its pushed commit changes: ask now, then at these offsets
// (a PR is usually opened, and CI restarts, right after a push).
const BURST = [1 * MIN, 2 * MIN, 5 * MIN];

// How the icon looks: the file per state and the theme color per state and CI.
export const ICONS = {
  open: "git-pull-request.svg",
  draft: "git-pull-request-draft.svg",
  merged: "git-merge.svg",
  closed: "git-pull-request-closed.svg",
};
const CI_WORDS = { passing: "checks passing", failing: "checks failing", running: "checks running", none: "no checks" };

// One `gh api -i` answer: the HTTP status (200, 304, 404, ...) or "error" when gh
// gave no HTTP answer at all, the headers that matter, and the parsed JSON body.
// A 304 makes gh exit 1 with "gh: HTTP 304"; its status line still comes first.
export function parseGh(result) {
  const out = result?.stdout ?? "";
  const status = /^HTTP\/\S+ (\d{3})/.exec(out);
  if (!status) return { status: "error", etag: null, remaining: null, pollInterval: null, body: null };

  const split = /\r?\n\r?\n/.exec(out);
  const head = split ? out.slice(0, split.index) : out;
  const rest = split ? out.slice(split.index + split[0].length) : "";
  const header = (name) => new RegExp(`^${name}:\\s*(.+?)\\s*$`, "im").exec(head)?.[1] ?? null;
  const number = (name) => {
    const v = header(name);
    return v === null ? null : Number(v);
  };

  let body = null;
  if (rest.trim()) {
    try {
      body = JSON.parse(rest);
    } catch {
      body = null;
    }
  }

  return {
    status: Number(status[1]),
    etag: header("etag"),
    remaining: number("x-ratelimit-remaining"),
    pollInterval: number("x-poll-interval"),
    body,
  };
}

// The newest PR from a `pulls?head=...&state=all&per_page=1` list, or null.
export function prSummary(pulls) {
  const pr = Array.isArray(pulls) ? pulls[0] : null;
  if (!pr) return null;

  const state = pr.merged_at ? "merged" : pr.state === "closed" ? "closed" : pr.draft ? "draft" : "open";
  return { number: pr.number, title: pr.title ?? "", url: pr.html_url, state, headSha: pr.head?.sha ?? null };
}

// CI of a commit from its `check-runs` list: running while any run isn't
// completed, failing when any finished badly, passing when some ran, else none.
export function ciRollup(checks) {
  const runs = checks?.check_runs ?? [];
  if (runs.some((r) => r.status !== "completed")) return "running";

  const bad = new Set(["failure", "timed_out", "cancelled", "action_required", "startup_failure"]);
  if (runs.some((r) => bad.has(r.conclusion))) return "failing";

  return (checks?.total_count ?? runs.length) > 0 ? "passing" : "none";
}

// When to ask GitHub again about one repo + bookmark, as a ms timestamp, or null
// for never. `e`: { at: last answer, since: last local change (bookmark or push),
// pushed: pushed commit or null, pr, ci, errors, pollInterval (s), remaining }.
export function nextDue(e) {
  if (!e.at) return null;

  // Failures back off on their own: 1, 2, 4 ... min, at most 30.
  if (e.errors > 0) return e.at + Math.min(30 * MIN, MIN * 2 ** (e.errors - 1));

  const times = [];
  const every = interval(e);
  if (every !== null) times.push(e.at + every);
  const step = BURST.map((d) => (e.since ?? 0) + d).find((t) => t > e.at);
  if (step !== undefined && e.pushed) times.push(step);
  if (!times.length) return null;

  let due = Math.min(...times);
  if (e.pollInterval) due = Math.max(due, e.at + e.pollInterval * SEC);
  if (e.remaining !== null && e.remaining !== undefined && e.remaining < LOW) due = Math.max(due, e.at + 10 * MIN);
  return due;
}

// The icon for a `space.prs` entry: its file and theme color (`t`: the theme).
// Closed stays grey, merged is purple, open and draft take their CI's color.
export function prLook(pr, t) {
  const color = pr.state === "merged" ? t.ansi5
    : !hasCi(pr) ? t.dim
    : { passing: t.ansi2, failing: t.ansi1, running: t.ansi3 }[pr.ci] ?? t.dim;
  return { icon: ICONS[pr.state] ?? ICONS.open, color };
}

// "#111 · Declared limits · checks passing · owner/repo · bookmark"
export function prTip(pr) {
  const ci = hasCi(pr) ? CI_WORDS[pr.ci] ?? null : pr.state;
  return [`#${pr.number}`, pr.title, ci, pr.repo, pr.bookmark].filter(Boolean).join(" · ");
}

// Whether a PR's CI matters: open and draft PRs still get pushed to and checked.
export function hasCi(pr) {
  return pr?.state === "open" || pr?.state === "draft";
}

// How often to look while nothing local changes; null: never.
function interval(e) {
  if (!e.pr) return e.pushed ? 15 * MIN : null;
  if (e.pr.state === "merged" || e.pr.state === "closed") return null;
  if (hasCi(e.pr) && e.ci === "running") return 45 * SEC;
  return 10 * MIN;
}
