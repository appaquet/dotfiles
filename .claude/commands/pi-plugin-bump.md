---
name: pi-plugin-bump
description: Bump Pi npm extension pins to the newest installable versions
---

# Bump Pi npm plugin pins

1. List the pins: `grep 'npm:' home-manager/modules/agentic/pi/plugins/default.nix`
2. Per package: `npm view <pkg> time --json`. Target = newest version published 3+ days before now. The global `~/.npmrc` sets `min-release-age=3`, which pi's npm installer enforces — never use `dist-tags.latest` blindly, too-fresh versions fail the live install with ETARGET. Re-verify publish dates at edit time.
3. Skip packages whose pinned version is already the newest eligible version
4. If a jump spans multiple minors, check the upstream release notes for breaking config changes; surface blockers to the user instead of bumping silently
5. Edit only the `@<ver>` suffixes in the file
6. Pretest each new pin with a scratch install: `npm install <pkg>@<ver> --prefix $(mktemp -d) --ignore-scripts` — uses the patched npm + min-release-age, so ETARGET means pick an older version
7. Eval: `HOST=deskapp ./x home check`
8. Commit the change with jj per the version-control workflow. Note: nix only sees git HEAD in this jj worktree, so commit before running nix builds/checks that must see the change
9. `~/.pi/agent/npm` updates on the next pi session; packages held back because their latest version is <3d old get picked up next cycle
