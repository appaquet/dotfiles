{
  nixantic.sources.version-control.instructions."rules/version-control-git" = {
    when = { scope }: scope.settings.versionControl.mode == "git";
    outputPath = "rules/version-control.md";
    heading = "Version Control (Git)";
    content = ''
      We are using `git` for version control.
      HARD GATE: inspect repository state before ANY write operation
      Never use `git stash` unless the user explicitly asks; uncommitted work may belong to someone else.

      ## Commands

      | Purpose | Command |
      |---------|---------|
      | Status | `git status --short --branch` |
      | Diff working tree | `git diff` (`--stat` for summary) |
      | Diff staged | `git diff --staged` (`--stat` for summary) |
      | Diff branch | `git diff --stat $(git merge-base HEAD origin/HEAD)..HEAD` then `git diff $(git merge-base HEAD origin/HEAD)..HEAD -- <file>` |
      | Current branch | `git branch --show-current` |
      | Recent commits | `git log --oneline -10` |
      | Stage files | `git add <files...>` |
      | Commit staged | `git commit -m "private: agent: description"` |

      ## Creating Commits

      Use normal Git commits for completed logical units of work.

      * Before starting implementation, inspect status and current branch.
      * Stage only files intentionally changed for the current task.
      * Commit after tests pass, or when the user explicitly asks for a checkpoint.
      * Do not rewrite history, rebase, reset, or force-push unless the user explicitly asks.

      ## Commit Messages

      Prefix commits with `"private: agent: "` so they can be easily identified and squashed before PR.
      Always use `-m "message"` for commands that expect a message since they could open an editor.

      <good-example>
      git commit -m "private: agent: fix validation bug"
      git commit -m "private: agent: feat(workspace): add collections API"
      </good-example>

      <bad-example>
      git commit -m "fix validation bug"
      git commit -m "feat(workspace): add collections API"
      </bad-example>

      ## State Verification

      HARD GATE: Verify repository state with `git status --short --branch` before ANY write command
      (`add`, `commit`, `reset`, `restore`, `checkout`, `switch`, `rebase`, `merge`, `cherry-pick`, `push`).
      Read the output — confirm the current branch and working tree match expectations. State changes
      from user actions or external tools at any time.

      * Expected: Clean working tree OR only changes you made in this session.
      * Shifted: Branch or working tree moved from previous operations — understand the new state and adjust.
      * Unexpected: Unknown modifications, conflicts, unrecognized content.

      If state is unexpected: STOP — do NOT attempt to fix, report and ask.

      ## Dangerous Operations

      Before using any destructive command, verify exactly what would be changed and ask the user.

      * `git reset --hard` - Wipes working tree and index changes.
      * `git restore` without paths - Wipes matching working tree changes.
      * `git checkout`/`git switch` with uncommitted changes - Can overwrite or strand work.
      * `git rebase` - Rewrites history and can require conflict resolution.
      * `git push --force` - Rewrites remote history.

      If the affected work has content or you're unsure: STOP and ask user.

      ## Recovery

      If something goes wrong, STOP and report before attempting recovery.

      * `git reflog` can locate prior refs for recovery.
      * `git status --short --branch` shows current conflict/working-tree state.
      * Do not run broad reset/restore commands to recover without explicit approval.

      ## Notes

      * Prefer `git diff --stat` before detailed diffs for large branches.
      * For `gh` commands, use `$(git branch --show-current)` for the current branch.
    '';
  };
}
