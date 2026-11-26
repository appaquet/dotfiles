// Unit suite for the spaces list's naming: space avatars (whole leading emoji or
// uppercased first letter) and repo names from a git common dir.

import { describe, expect, test } from "bun:test";
import { repoName, spaceAvatar } from "./names.js";

describe("spaceAvatar", () => {
  test("uppercases a plain name's first letter", () => {
    expect(spaceAvatar("dotfiles")).toBe("D");
  });

  test("keeps a whole leading emoji", () => {
    expect(spaceAvatar("🚀 demo")).toBe("🚀");
    expect(spaceAvatar("👩‍💻 work")).toBe("👩‍💻");
    expect(spaceAvatar("🇨🇦 home")).toBe("🇨🇦");
    expect(spaceAvatar("👍🏽 ok")).toBe("👍🏽");
  });

  test("falls back to ? for an empty name", () => {
    expect(spaceAvatar("")).toBe("?");
  });
});

describe("repoName", () => {
  test("names a normal repo after the folder holding .git", () => {
    expect(repoName("/code/dotcore/.git")).toBe("dotcore");
  });

  test("names a bare repo after itself, without .git", () => {
    expect(repoName("/code/dotcore.git")).toBe("dotcore");
    expect(repoName("/code/dotcore")).toBe("dotcore");
  });

  test("names a hidden bare repo after its project", () => {
    expect(repoName("/code/dotcore/.bare")).toBe("dotcore");
    expect(repoName("/code/dotcore/.bare/")).toBe("dotcore");
  });
});
