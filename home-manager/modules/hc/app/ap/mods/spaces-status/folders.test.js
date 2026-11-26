// Unit suite for the folder grouping of the spaces sidebar: the name-prefix split, one header
// per folder placed at its first member, suffix-only display names, and the folder of an active
// space. Only the module under test and bun's runner are imported.

import { describe, expect, test } from "bun:test";
import { assignFolders, displayNameFor, folderOfSpace, foldOf, groupFolders, splitName } from "./folders.js";

const space = (id, name) => ({ w: { id, name } });
const main = (id, name) => ({ ...space(id, name), tree: null, kids: 0, hidden: false });
const worktree = (id, name, kids = 0) => ({ ...space(id, name), tree: "└─", hidden: false, ...kids });
const list = (...rows) => rows.map((r, i) => ({ ...r, i }));

describe("splitName", () => {
  test("splits at the first hyphen", () => {
    expect(splitName("velix-code")).toEqual({ prefix: "velix", suffix: "code" });
    expect(splitName("velix-code-foo")).toEqual({ prefix: "velix", suffix: "code-foo" });
  });

  test("rejects a name with no usable split", () => {
    expect(splitName("velix")).toBeNull();
    expect(splitName("-code")).toBeNull();
    expect(splitName("velix-")).toBeNull();
    expect(splitName("")).toBeNull();
    expect(splitName(undefined)).toBeNull();
  });
});

describe("foldOf / displayNameFor", () => {
  test("derives the folder from the prefix", () => {
    expect(foldOf("velix-code")).toBe("velix");
    expect(foldOf("velix")).toBeNull();
  });

  test("strips the folder prefix, keeps the full name when it does not match", () => {
    expect(displayNameFor("velix-code", "velix")).toBe("code");
    expect(displayNameFor("velix-code-foo", "velix")).toBe("code-foo");
    expect(displayNameFor("feat-x", "velix")).toBe("feat-x");
    expect(displayNameFor("velix-code", null)).toBe("velix-code");
  });
});

describe("assignFolders", () => {
  test("tags mains by their name and worktree rows with their parent's folder", () => {
    const rows = assignFolders(list(main("a", "velix-code"), worktree("w", "feat-x"), main("b", "other")));

    expect(rows.map((r) => [r.row.w.id, r.folder])).toEqual([
      ["a", "velix"],
      ["w", "velix"],
      ["b", null],
    ]);
  });

  test("a hyphenless main resets the folder for its worktrees", () => {
    const rows = assignFolders(list(main("a", "velix-code"), main("b", "velix"), worktree("w", "feat-x")));

    expect(rows.map((r) => [r.row.w.id, r.folder])).toEqual([
      ["a", "velix"],
      ["b", null],
      ["w", null],
    ]);
  });
});

describe("groupFolders", () => {
  test("groups members under one folder header at its first member", () => {
    const items = groupFolders(list(main("a", "velix-code"), worktree("w", "feat-x"), main("b", "velix-docs")));

    expect(items.map((i) => i.kind)).toEqual(["folder", "row", "row", "row"]);
    expect(items[0]).toMatchObject({ name: "velix", count: 3 });
    expect(items.slice(1).map((i) => [i.row.w.id, i.displayName])).toEqual([
      ["a", "code"],
      ["w", "feat-x"],
      ["b", "docs"],
    ]);
  });

  test("keeps a folder header once even when its members are spread out", () => {
    const items = groupFolders(list(main("a", "velix-code"), main("o", "other"), main("b", "velix-docs")));

    expect(items.map((i) => i.kind)).toEqual(["folder", "row", "row", "row"]);
    expect(items.filter((i) => i.kind === "folder")).toHaveLength(1);
    expect(items[0].name).toBe("velix");
    expect(items[0].count).toBe(2);
  });

  test("an unclued row keeps its full name and sits outside the folder", () => {
    const items = groupFolders(list(main("a", "velix"), main("b", "velix-docs")));

    expect(items.map((i) => (i.kind === "folder" ? ["folder", i.name] : [i.kind, i.displayName]))).toEqual([
      ["row", "velix"],
      ["folder", "velix"],
      ["row", "docs"],
    ]);
  });
});

describe("folderOfSpace", () => {
  const repos = { a: { linked: false, repo: "R" }, w: { linked: true, repo: "R" }, b: { linked: false, repo: "R" } };

  test("main spaces take the prefix from their name", () => {
    const listRows = list({ ...main("a", "velix-code"), g: repos.a }, { ...main("b", "velix-docs"), g: repos.b });

    expect(folderOfSpace(listRows, { id: "a" })).toBe("velix");
    expect(folderOfSpace(listRows, { id: "b" })).toBe("velix");
  });

  test("worktrees follow their main's folder", () => {
    const listRows = list({ ...main("a", "velix-code"), g: repos.a }, { ...worktree("w", "feat-x"), g: repos.w });

    expect(folderOfSpace(listRows, { id: "w" })).toBe("velix");
  });

  test("a worktree without its main is its own space", () => {
    const listRows = list({ ...worktree("w", "velix-feat-x"), tree: null, g: repos.w });

    expect(folderOfSpace(listRows, { id: "w" })).toBe("velix");
  });

  test("returns null for a space it cannot see", () => {
    expect(folderOfSpace(list(main("a", "velix-code")), { id: "z" })).toBeNull();
  });
});
