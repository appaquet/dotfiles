
# Version Control (Jujutsu)

Using `jj` (collocated with git). Note: always detached head state.

## Commit Messages

ALL commits: prefix `"private: claude: "` for `jj new -m` and `jj commit -m`
✓ `jj commit -m "private: claude: fix validation bug"`

CRITICAL: Always use `-m "message"` - never `jj commit` alone (tries to open editor)

## When to Create New Change

Create when:

- Starting distinct task (bug fix, feature, refactor)
- Addressing review comments (even if related)
- Switching context
- Explicitly requested
- Exception: Skip for read-only ops (viewing, testing without changes, searching)

Stay in current when:

- Making related fixes
- Iterating same problem
- Continuing same task

## Commands

| Purpose | Command |
|---------|---------|
| New change | `jj new -m "private: claude: description"` |
| Commit current | `jj commit -m "private: claude: description"` |
| Diff with git style | `jj diff --git` |
| Main branch name | `jj-main-branch` |
| Current branch | `jj-current-branch` |
| Previous branch | `jj-prev-branch` (for stacked PRs, returns `dev` if not stacked) |
| Diff working changes | `jj-diff-working --git` (add `--stat` for files) |
| Diff branch | `jj-diff-branch --git` (works with stacked/standalone PRs) |
| Stacked branches list | `jj-stacked-branches` |
| Stacked file stats | `jj-stacked-stats` |

## Important Notes

- Use `--git` flag for comprehensible diff output
- For `gh` commands: Use `$(jj-current-branch)` since always detached
- Never revert changes not made by you - ask for clarification
