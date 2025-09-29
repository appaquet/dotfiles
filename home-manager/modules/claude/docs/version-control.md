
# Version control

* I use jujutsu (`jj`) for most of the repositories I will use you with, but they are collocated
  with git, which means that you may fallback to git for read-only methods. But be careful, `jj`
  always have a detached head.

* `jj` uses the concept of changes that have immutable change IDs that have different git commits
  over time associated to them.

* `jj` uses the concept of bookmarks that are like branches, but they can be seen like tags that can

* Create new change when:
  * Starting a distinct logical task (bug fix, feature, refactor)
  * Addressing review comments (even if related to current work)
  * Switching context to unrelated work  
  * Explicitly requested to create a new change
  * Exception: Only skip for read-only operations (viewing files, running tests without changes, checking status, searching)

  * **ALL** commit messages you create MUST start with "private: claude: " prefix when Claude is making changes
    * ✅ Correct: `jj commit -m "private: claude: fix validation loop bug"`
    * ❌ Wrong: `jj commit -m "fix(component): correct validation loop bug"`
    * This applies to BOTH `jj new -m` and `jj commit -m` commands

  * **CRITICAL**: ALWAYS use `jj commit -m "message"` - NEVER use `jj commit` or `jj new` alone as
    it will try to open an editor which doesn't work in this environment.

* Stay in current change when:
  * Making related fixes (e.g., all lint issues from same feature)
  * Iterating on the same problem
  * Continuing work on same logical task

* When diffing using `jj`, prefer using `--git` to get a more comprehensible output that is similar
  to git's output.

* Very important note about `gh`: since `jj` is almost always in a detached head state, you should
  use `jj-current-branch` to get the current branch name and pass it to `gh` commands that require a
  branch name. For example, `gh pr view $(jj-current-branch)`.

* If you notice a change in the code that wasn't done by you **DON'T REVERT IT**. You have to
  remember that you are an AI assistant, and I or other AI assistants may have made changes to the
  code. If you think the change is wrong, ask for clarification instead of reverting it.

* Cheat sheet
  * Create a new empty change with a description: `jj new -m "private: claude: description of the change"`
  * Commit current changes to current change with a message: `jj commit -m "private: claude: description of the change"`
  * I have a few extra shell functions to help dealing with branches:
    * `jj-main-branch` to get the main/trunk branch name
    * `jj-current-branch` to get the current branch name
    * `jj-prev-branch` to get the name of the previous branch. Useful for stacked PRs, and will return
      `dev` if the PR isn't stacked
    * `jj-diff-working --git` to diff the current working changes from last bookmarked
      change (use `--stat` for list of files)
    * `jj-diff-branch --git` to diff the current branch with the previous branch, which
      works with stacked PRs or standalone ones (use `--stat` for list of files)
    * `jj-stacked-branches` to get the list of branches from the trunk branch to the current branch
    * `jj-stacked-stats` list all files changed in each changes of the stacked branches
