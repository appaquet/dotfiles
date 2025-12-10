
# Version Control (Jujutsu)

Using `jj` (collocated with git). Always detached head state.

## Commit Messages

ALL commits: prefix `"private: claude: "` for `jj new -m` and `jj commit -m`
Always use `-m "message"` (never `jj commit` alone - opens editor)

✓ `jj commit -m "private: claude: fix validation bug"`

## When to Create New Change

Create new change at milestones:
- Before starting implementation (after planning)
- After tests pass
- Before refactoring working code
- Before addressing review comments
- When switching to different area of codebase
- Skip for: read-only ops, iteration within same logical step

Default to creating changes - easier to squash later than split.

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
