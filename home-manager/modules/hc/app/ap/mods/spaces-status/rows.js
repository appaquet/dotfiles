// Row grouping for the spaces list: each worktree space moves under its repo's
// first main-checkout space, with tree markers and the parent map the `goto`
// picker reads. Pure — no app imports, so bun can test it directly.

// `list`: rows in spaces order, each `{ w, i, g }` with `g` a place's git info
// (`repo` key, `linked` true for a worktree) or null off a repo.
// `folded`: the repos whose worktree rows are hidden; their kids keep their
// place and markers so unfolding is a redraw, nothing recomputed.
export function groupRows(list, folded) {
  const hidden = (r) => Boolean(folded?.has(r.g.repo));
  const mains = new Set(list.filter((r) => r.g && !r.g.linked).map((r) => r.g.repo));
  const nested = (r) => r.g?.linked && mains.has(r.g.repo);
  const out = [];
  const parents = {}; // worktree space id -> the main space it's listed under
  const placed = new Set(); // repos whose worktrees are listed (under the first of its spaces)
  for (const r of list) {
    if (nested(r)) continue;
    const kids = r.g && !r.g.linked && !placed.has(r.g.repo)
      ? list.filter((k) => nested(k) && k.g.repo === r.g.repo)
      : [];
    if (kids.length) placed.add(r.g.repo);
    out.push({ ...r, tree: null, kids: kids.length });
    kids.forEach((k, n) => {
      out.push({ ...k, tree: n === kids.length - 1 ? "└─" : "├─", hidden: hidden(k) });
      parents[k.w.id] = r.w.id;
    });
  }
  return { rows: out, parents };
}
