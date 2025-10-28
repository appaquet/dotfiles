---
name: update-codex
description: Update openai codex's version
model: haiku
---

# Update codex

## Context

I have an overlay for codex that make sure I use the latest version. This task is about updating the
latest version of it.

## Instructions

1. Fetch the release page of the codex project from github and get version number of the latest:
   `https://github.com/openai/codex/releases`

2. Update `overlays/codex/default.nix`:
   * update the `version` field
   * change to an empty value the `hash` and `cargoHash` values

3. At the root of the repo, run `./x home build`, update the hash values in `default.nix` with the
   expected values. You'll have to run it twice to get the two values

4. At the root of the repo, create a new jj change: `jj commit -m "codex++" overlays/codex`
