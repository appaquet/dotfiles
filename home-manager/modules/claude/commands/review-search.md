---
name: review-search
description: Search for REVIEW comments in the codebase
---

# Search Review Comments

1. Search for REVIEW comments using the `Grep` tool:

   ```
   Grep(pattern="// REVIEW:", output_mode="content")
   ```

   * Adapt comment prefix for the codebase language
   * Ignore results in `proj/` (project documentation)
   * Do NOT use Bash rg with glob exclusions - they fail silently
   * A review comment with `>>` and `<<` indicates a multi-line comment;
     lines between `>>` and `<<` are part of the review comment.

2. If no comments found, verify you're at repository root and pattern matches the language.

3. If still no comments OR user explicitly requested, check PR comments:
   * Get current branch: `jj-current-branch`
   * Check PR: `gh pr view $(jj-current-branch)`

**If invoked directly by user, STOP** after reporting findings. If invoked from another command,
continue with that command's workflow.
