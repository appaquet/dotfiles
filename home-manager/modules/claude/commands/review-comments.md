---
name: review-comments
description: Review and address REVIEW comments left in code or pull requests
---

We want to review and fix the comments I've left in the code. I use `// REVIEW:` prefix (adapt to
each language) to mark comments that need to be reviewed and addressed.

1. Search for REVIEW comments in the codebase:
   * At the **root of the repository**, use `rg -n "// REVIEW:"`
   * If no comments found, verify you're at repository root and not limiting by file type
   * If still no comments OR explicitly requested, check PR comments using:
     - Get current branch: `jj-current-branch`
     - Check PR comments: `gh pr view $(jj-current-branch)` and `gh api repos/owner/repo/pulls/PR_NUMBER/comments`

2. Categorize each review comment:
   * **Action items**: Code fixes, feature implementations, refactoring needed
   * **Context/Pointers**: Information to help with other tasks
   * **Questions**: Clarifications needed about the code

   **Note**: Don't reply in code comments - communicate directly with me for questions

3. Create action plan:
   * Build internal TODO list from review comments
   * Update `PR.md` TODO section with identified tasks
   * Prioritize tasks based on dependencies

4. Execute tasks systematically:
   * Address each task one by one
   * Remove associated review comments after completion
   * Update `PR.md` TODO section progress as you go

5. Final verification:
   * Search again for any remaining review comments: `rg -n "// REVIEW:"`
   * Ensure `PR.md` reflects all completed work
   * Run tests, formatting, and linting to fix any issues

6. Notify completion with `notify "Review comments addressed"`
