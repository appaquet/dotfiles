// Unit suite for the spaces list's row grouping: worktree rows nested under
// their repo's first main-checkout space, tree markers, kids counts, the
// parents map the `goto` picker reads, and the fold's hidden marking. Only the
// module under test and bun's runner are imported.

import { describe, expect, test } from "bun:test";
import { groupRows } from "./rows.js";

// A space `{ w: { id, name } }` with git info `g` shaped like the mod's:
// `repo` is the machine-scoped repo key, `linked` true for a worktree.
const space = (id, name) => ({ w: { id, name } });
const main = (id, name, repo) => ({ ...space(id, name), g: { repo, linked: false } });
const worktree = (id, name, repo) => ({ ...space(id, name), g: { repo, linked: true } });
const plain = (id, name) => ({ ...space(id, name), g: null });

const REPO = '["machine","/code/dotcore"]';
const names = (rows) => rows.map((r) => [r.w.name, r.tree, r.kids, r.hidden]);

describe("groupRows", () => {
  test("nests a repo's worktrees under its first main space", () => {
    const { rows, parents } = groupRows([main("m", "dotcore", REPO), worktree("w1", "spike", REPO)]);
    expect(names(rows)).toEqual([
      ["dotcore", null, 1, undefined],
      ["spike", "└─", undefined, false],
    ]);
    expect(parents).toEqual({ w1: "m" });
  });

  test("marks every worktree but the last with ├─ and the last with └─", () => {
    const { rows } = groupRows([main("m", "dotcore", REPO), worktree("w1", "a", REPO), worktree("w2", "b", REPO), worktree("w3", "c", REPO)]);
    expect(rows.map((r) => r.tree)).toEqual([null, "├─", "├─", "└─"]);
    expect(rows[0].kids).toBe(3);
  });

  test("lists a repo's worktrees only under its first main space", () => {
    const { rows } = groupRows([main("m1", "dotcore", REPO), worktree("w", "spike", REPO), main("m2", "dotcore again", REPO)]);
    expect(rows.map((r) => r.w.id)).toEqual(["m1", "w", "m2"]);
    expect(rows.map((r) => r.kids)).toEqual([1, undefined, 0]);
  });

  test("leaves a worktree unnested when its repo has no main space", () => {
    const { rows, parents } = groupRows([worktree("w", "spike", REPO), plain("p", "scratch")]);
    expect(names(rows)).toEqual([
      ["spike", null, 0, undefined],
      ["scratch", null, 0, undefined],
    ]);
    expect(parents).toEqual({});
  });

  test("marks a folded repo's worktree rows hidden and keeps its main visible", () => {
    const folded = new Set([REPO]);
    const { rows, parents } = groupRows([main("m", "dotcore", REPO), worktree("w", "spike", REPO)], folded);
    expect(rows[0].hidden).toBeUndefined();
    expect(rows[1].hidden).toBe(true);
    expect(parents).toEqual({ w: "m" });
  });

  test("keeps another repo's worktrees visible while one is folded", () => {
    const other = '["machine","/code/exomind"]';
    const folded = new Set([REPO]);
    const { rows } = groupRows([main("m", "dotcore", REPO), worktree("w1", "spike", REPO), main("o", "exomind", other), worktree("w2", "side", other)], folded);
    expect(rows.map((r) => [r.w.name, r.hidden])).toEqual([
      ["dotcore", undefined],
      ["spike", true],
      ["exomind", undefined],
      ["side", false],
    ]);
  });
});
