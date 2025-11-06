---
name: review-comments
description: Review and address REVIEW comments left in code or pull requests
---

# Review Comments

We want to review and fix the comments I've left in the code. I use `// REVIEW:` prefix (adapt to
each language) to mark comments that need to be reviewed and addressed.

1. Search for REVIEW comments in the codebase:
   * At the **root of the repository**, use `rg -n "// REVIEW:"`
     * **NEVER** look for comments in sub-directories directly, always start at the root of the repository
     * **NEVER** assume that there aren't any comments left. If you can't find them, it means you are not
       searching correctly.
   * If no comments found, verify you're at repository root and not limiting by file type
   * If, and only if, still no comments OR that I explicitly requested it, check PR comments using:
     * Get current branch: `jj-current-branch`
     * Check PR comments: `gh pr view $(jj-current-branch)` and `gh api repos/owner/repo/pulls/PR_NUMBER/comments`

2. For each comment found, **ALWAYS** look at the surrounding and/or related code to fully
   understand the context. If you aren't sure about a comment, **ALWAYS** use `AskUserQuestion`
   tool to clarify. You **MUST** fully understand the context before taking any action, using the
   context understanding checklist.

3. **ALWAYS** create an action plan:
   * Build internal TODO list from review comments
   * Update `PR.md` TODO section with identified tasks
   * Prioritize tasks based on dependencies

4. Execute tasks systematically:
   * Address each task one by one
   * Always make sure you fully understand the context before making changes
   * Remove associated review comments after completion
   * Update `PR.md` TODO section progress as you go

5. Final verification:
   * Search again for any remaining review comments: `rg -n "// REVIEW:"`
   * Ensure `PR.md` reflects all completed work
   * Run tests, formatting, and linting to fix any issues

## Important rules

* **NEVER** replace REVIEW comments with "// Note:" explanations or similar. Always report them to me if you
  believe they are unnecessary, and keep the REVIEW comment in the code.

* **NEVER** Take decision of not taking action on a comment that was an action item on the premise
  that you think it is not needed. If you want to pushback on a comment, you must communicate with
  me. You can fix the rest of the comments, but then clearly tell me that you did not address the
  comment and why you think it is not needed. I will then decide if it is needed or not.
