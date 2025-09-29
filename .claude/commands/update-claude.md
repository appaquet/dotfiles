---
name: update-claude
description: Update claude code's version
---

## Context
I have an overlay for claude code that make sure I use the latest version. This task is about
updating the latest version of claude code.

## Instructions

All of these steps must be done inside `overlays/claude-code` directory, except step 4 and 5.

1. Run `./update.sh` to update the npm lock file

2. Lookup the new version in the `package-lock.json` file that was updated

3. Update the `default.nix` file:
   * update the `version` field
   * change to an empty value the `hash` and `npmDepsHash` values

4. At the root of the repo, run `./x home build`, update the hash values in `default.nix` with the
   expected values. You'll have to run it twice to get the two values

5. At the root of the repo, create a new jj change: `jj commit -m "claude++" overlays/claude-code`
   **IMPORTANT**: don't prefix with `private: claude:`, `claude++` is what it needs to be!
