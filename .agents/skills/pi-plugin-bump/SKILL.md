---
name: pi-plugin-bump
description: Bump Pi npm extension pins to the newest installable versions
---

# Bump Pi npm plugin pins

All paths below are relative to the jj workspace you are working in, which is either the default
checkout (`~/dotfiles`) or a task workspace (`~/dotfiles/.workspaces/<name>`). Pick it at the start —
`jj ls` names it — and run every edit, `./x` and `jj` command from that root. `./x` resolves its flake
from its own script directory, so a parent or sibling checkout's `./x` builds a different tree. Never
edit in one workspace and eval/switch in another. End the report by naming the workspace path so AP
knows where to run the switch.

1. List the pins: `grep 'npm:' home-manager/modules/agentic/pi/plugins/default.nix`
2. Per package: `npm view <pkg> time --json`. Target = newest version published 3+ days before now. The global `~/.npmrc` sets `min-release-age=3`, which pi's npm installer enforces — never use `dist-tags.latest` blindly, too-fresh versions fail the live install with ETARGET. Re-verify publish dates at edit time.
3. Skip packages whose pinned version is already the newest eligible version
4. Per bumped package, check the upstream release notes for the pinned→new range for breaking config changes (`npm view <pkg> repository.url`, then GitHub releases; fall back to commit history when the repo publishes no releases); surface blockers to the user instead of bumping silently
5. Edit only the `@<ver>` suffixes in the file
6. Pretest each new pin with a scratch install: `npm install <pkg>@<ver> --prefix $(mktemp -d) --ignore-scripts` — uses the patched npm + min-release-age, so ETARGET means pick an older version
7. Verify the eval sees the new pins, not just that the eval succeeds:
   - `./x home check` (exit 0). It targets the local host by default (`HOST` falls back to `uname -n`);
     set `HOST=<name>` only when targeting another host.
   - `nix eval --impure --json ".#homeConfigurations.\"<home-config>\".config.dotfiles.pi.settings.packages"`,
     where `<home-config>` is the name `home check` printed (`Checking home <home-config>`), must list
     the exact new specs. If it still shows the old ones, the workspace or file is wrong — stop and fix
     that before committing. `home check` is `nix eval --raw`, so it builds nothing: the generation path
     it prints need not exist in the store.
8. Commit with jj per the version-control workflow, then confirm with `jj ls` that the commit sits on
   this workspace's `@-`.
9. Applying: `./x home switch` in this workspace; the next pi launch rewrites
   `~/.pi/agent/settings.json` (`packages`) and installs into `~/.pi/agent/npm`. Prove it by reading
   `.packages` plus each `~/.pi/agent/npm/node_modules/<pkg>/package.json` version. A switch run
   against a workspace without the change leaves the old generation active and installs nothing.
   Packages held back because their latest version is <3d old get picked up next cycle.
