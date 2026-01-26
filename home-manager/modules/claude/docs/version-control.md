# Version Control (Jujutsu)

Using `jj` (collocated with git). Always detached head state.

## State Verification

Before any jj operation, verify working copy state with `jj status`:

* **Expected**: Clean working copy OR only changes you made in this session
* **Unexpected**: Pre-existing changes, unknown modifications, conflicts

**If state is unexpected: STOP immediately.**
* Do NOT create new changes, commit, or continue working
* Do NOT attempt to "clean up" or "fix" the state
* Report what you found and ask for clarification

This prevents accidentally orphaning user changes or reverting work.

## Creating Changes

**jj commit vs jj new:**

* `jj commit -m "msg"` - Finalize CURRENT changes with message, create new empty change
* `jj new -m "msg"` - Create NEW empty change with message (current changes stay in parent)

Use `commit` after changes. Use `new` before changes.
Run `jj status` before committing to verify changes are in expected place.

**When to create changes:**

* Before starting implementation (after planning)
* After tests pass
* Before refactoring working code
* Before addressing review comments
* When switching to different area of codebase
* Skip for: read-only ops, iteration within same logical step

Default to more changes - easier to squash than split.

## Commit Messages

Prefix commits with `"private: claude: "` so they can be easily identified and squashed before PR.
Always use `-m "message"` for commands that expect a message since they could open editor:
  `jj commit -m ...
  `jj new -m ...`
  `jj squash -m ...`

<good-example>
jj commit -m "private: claude: fix validation bug"
jj commit -m "private: claude: feat(workspace): add collections API"
</good-example>

<bad-example>
jj commit -m "fix validation bug"
jj commit -m "feat(workspace): add collections API"
</bad-example>

## Commands

| Purpose | Command |
|---------|---------|
| Commit current | `jj commit -m "private: claude: description"` |
| New empty change | `jj new -m "private: claude: description"` |
| Squash current into parent | `jj squash -m "private: claude: description"` |
| Diff (git style) | `jj diff --git` |
| Diff working | `jj-diff-working --git` (`--stat` for files) |
| Diff branch | `jj-diff-branch --git` |
| Current branch | `jj-current-branch` |
| Main branch | `jj-main-branch` |
| Previous branch | `jj-prev-branch` |
| Stacked branches | `jj-stacked-branches` |
| Stacked stats | `jj-stacked-stats` |

## Notes

* Use `--git` flag for readable diff output
* For `gh` commands: use `$(jj-current-branch)` since always detached
* Never revert, restore, or abandon changes not made by you in this session - STOP and ask
* If `jj status` shows unexpected state, do not proceed - report and ask for clarification
