{
  nixantic.sources.version-control.instructions."rules/version-control-jj" = {
    when = { scope }: scope.settings.versionControl.mode == "jj";
    outputPath = "rules/version-control.md";
    heading = "Version Control (Jujutsu)";
    content = ''
      We are using Jujutsu (`jj`), in collocated mode with git, which is always detached head state.

      A jj change is like git commit, but keeps id even if changed. When mentionning commit in instructions, this means jj change.

      Staging changes doesn't work like in git, where you usually create new jj change, work on it, then commit. So it's normal to be working on an empty jj change.

      Before any jj write operation, check state with `jj ls` in separate tool call. May have concurrent changes and state drift, never combine state verification and write in same command.

      Never use `git`, unless absolutely necessary, and should only be done for read-only. Write operations should be user approved.
      Never use `git stash` to temporarily save changes, use `jj new` to fork instead.

      ## Commands

      | Purpose | Command |
      |---------|---------|
      | Commit current | `jj commit -m "private: agent: description"` |
      | Commit specific files of current | `jj commit -m "private: agent: description" <files...>` |
      | New empty change | `jj new -m "private: agent: description"` |
      | Rename current change | `jj describe -m "private: agent: description"` |
      | Squash current into parent, changing parent message | `jj squash -m "private: agent: description"` |
      | Squash current into parent, keep parent message | `jj squash -u` |
      | Squash specific files to parent | `jj squash -u <files...>` |
      | Split a jj change, selecting files to remain in original | `jj split -m "private: agent: description" <files...>` |
      | Diff (git style) | `jj diff --git` |
      | Diff working, including revent private changes, not just @ | `jj-diff-working --git` (`--stat` for files) |
      | Diff branch | `jj-diff-branch --git` |
      | Current branch | `jj-current-branch` |
      | Main branch | `jj-main-branch` |
      | Previous branch | `jj-prev-branch` |
      | Stacked branches | `jj-stacked-branches` |
      | Stacked stats | `jj-stacked-stats` |

      ## Creating Changes

      Commands:

      * `jj commit -m "msg"` - Finalize CURRENT changes with message, create new empty change
      * `jj new -m "msg"` - Create NEW empty change with message (current changes stay in parent)
      * `jj describe -m "msg"` - Set message on current `@` without creating a new change

      Use `commit` after changes. Before starting new work, check if `@` is already empty:

      * `@` is empty → `jj describe -m "..."` (avoid `jj new` which creates an orphaned empty intermediate)
      * `@` has changes → `jj new -m "..."`

      When to create changes:

      * Before starting implementation (after planning)
      * After tests pass
      * Before refactoring working code
      * Before addressing review comments
      * When switching to different area of codebase
      * Skip for: read-only ops, iteration within same logical step

      Default to more changes - easier to squash than split
      Never clean up commit history (squash, abandon empty changes, reorder). User handles that

      ## Commit Messages

      Prefix commits with `"private: agent: "` so they can be easily identified and squashed before PR
      Always use `-m "message"` for commands that expect a message since they could open editor:
        `jj commit -m ...`
        `jj new -m ...`
        `jj split -m ...`
        `jj squash -m ...` => will change destination message, use -u to keep destination (always `jj ls` before)

      <good-example>
      jj commit -m "private: agent: fix validation bug"
      jj commit -m "private: agent: feat(workspace): add collections API"
      </good-example>

      <bad-example>
      jj commit -m "fix validation bug"
      jj commit -m "feat(workspace): add collections API"
      </bad-example>

      ## State Verification

      HARD GATE: Verify graph state with `jj ls` before ANY write command (`commit`, `new`, `describe`, `squash`, `abandon`, `restore`, `rebase`). Read the output — confirm `@` parent and working copy match expectations. State changes from your operations, user actions, or external tools at any time. `jj ls` is the equivalent of `jj status` and `jj log` combined in one output.

      * Expected: Clean working copy OR only changes you made in this session
      * Shifted: Graph moved from previous operations or user actions — understand the new
        state and adjust your command target accordingly
      * Unexpected: Unknown modifications, conflicts, unrecognized content

      If state is unexpected: STOP — do NOT attempt to fix, report and ask

      ## Dangerous Operations

      Before using any of these, run `jj diff --stat -r <change>` to verify the change is truly empty/safe:

      * `jj abandon` - Removes change from history. Descendants re-parent onto abandoned change's parent
      * `jj restore` (without paths) - Wipes all changes in target revision
      * `jj squash --into <non-parent>` - Moves content across non-adjacent changes, graph shifts unpredictably
      * `jj rebase -r` - Extracts change from chain, descendants lose its contribution

      If the change has content or you're unsure: STOP and ask user

      <bad-example>
      jj squash --into @--    # Moved content across non-adjacent changes
      jj abandon @--          # Destroyed change with actual content (didn't verify first)
      # Result: cascading abandonments, all implementation work lost
      </bad-example>

      ## Revset Safety

      * `@` and `@-`: safe for standard operations (commit, new, squash into parent)
      * `@--` and beyond: NEVER use for write operations — relative targets shift after graph modifications
      * After any graph-modifying operation: re-run `jj log` before using relative revsets
      * For destructive operations: capture the change ID from `jj log`, use it directly

      ## Recovery

      If something goes wrong, STOP and report before attempting recovery:

      * `jj undo` - Reverses last operation. NOT stackable (second undo = redo)
      * `jj op log` - Shows all operations with IDs
      * `jj --at-op <op_id> log` - Inspect repo state at a past operation (read-only)
      * `jj op restore <op_id>` - Restores repo to a specific past state

      For multi-step recovery: `jj op log` → `jj --at-op` to inspect → `jj op restore`. Not repeated `jj undo`

      ## Notes

      * Use `--git` flag for readable diff output
      * For `gh` commands: use `$(jj-current-branch)` since always detached
    '';
  };
}
