---
name: review-load
description: Load code review findings from the codebase
---

# Load Code Review Findings

1. Search for REVIEW comments in the codebase:
   * At the **root of the repository**, use `rg -n "// REVIEW:"`
     * **NEVER** look for comments in sub-directories directly, always start at the root of the repository
     * **NEVER** assume that there aren't any comments left. If you can't find them, it means you are not
       searching correctly.
   * If no comments found, verify you're at repository root and not limiting by file type
   * If, and only if, still no comments OR that I explicitly requested it, check PR comments using:
     * Get current branch: `jj-current-branch`
     * Check PR comments: `gh pr view $(jj-current-branch)` and `gh api repos/owner/repo/pulls/PR_NUMBER/comments`

**STOP after loading.** Report findings and wait for instruction.
