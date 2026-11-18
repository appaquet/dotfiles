# Git and Jujutsu tooling

## Layout

- `jujutsu.nix`: JJ settings, revset aliases (`proj()`, `nearest_proj(from)`, `private()`, ...)
  and command aliases (`tug`, ...), plus the fish abbreviations (`jjt`, `jjpt`, `jjwd`, ...)
- `scripts/jj-lib.sh`: shared shell helpers. `jj-utils.nix` puts it in front of every
  `scripts/<command>.sh` body, so a body holds only that command's logic
- `checks/jj-test-lib.sh`: shared test helpers. `checks/default.nix` puts it in front of every
  `checks/<suite>.sh`, puts `jj-utils` on `PATH`, and sets `JJ_CONFIG` to the test identity plus
  the real aliases from `jujutsu.nix`

## Reuse before adding

Before writing a command, lookup or test helper, read the three files above. Then pick the
first option that fits:

1. Compose existing revset aliases inline, or add a small one to `jujutsu.nix` when two callers
   need the same lookup
2. Call or extend a `jj-lib.sh` helper, or add a small one when a second command needs it
3. Write the logic in the command body

- Never re-implement a lookup a revset can express (graph walks, ID lists, loops over revisions)
- Never copy aliases into scripts or test repos: `JJ_CONFIG` already loads them
- Tests use `assert_*`, `rev_of`, `op_id`, `init_repo` and `finish` from `jj-test-lib.sh`. A
  suite defines only its own fixtures. A new suite is a `checks/<suite>.sh` plus one name in
  `checks/default.nix`

## Keep changes small

- Change only the lines the feature needs. Don't restructure or re-wrap code you aren't changing
- Guard what can realistically go wrong for AP's own use, and let JJ enforce what it already
  enforces (immutability, conflicts, refused rewrites)
- Treat a reviewer's extra guard as a proposal. If it adds more than a few lines, ask AP first
- Test the golden path and the failures that would lose work. Don't add a test for every guard
