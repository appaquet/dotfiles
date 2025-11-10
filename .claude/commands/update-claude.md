---
name: update-claude
description: Update claude code's version
model: haiku
---

# Update claude code

## Context
I have an overlay for claude code that make sure I use the latest version. This task is about
updating the latest version of claude code.

## Instructions

All of these steps must be done inside `overlays/claude-code` directory, except step 4 and 5.

1. Run `./update.sh` to update the npm lock file

2. Read `package-lock.json` around line 12 to find the new version number

3. Update the `default.nix` file:
   * Update the `version` field to the new version from step 2
   * Set `hash = "";` (empty string)
   * Set `npmDepsHash = "";` (empty string)

4. Run the `/update-hash` command to update both hash values

5. At the root of the repo, create a new jj change: `jj commit -m "claude++" overlays/claude-code`
   **IMPORTANT**: don't prefix with `private: claude:`, `claude++` is what it needs to be!
