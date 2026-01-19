---
name: review-fix
description: Fix REVIEW comments left in code or pull requests
---

# Fix review comments

We want to review and fix the REVIEW comments I've left in the code.

1. Unless we just searched or decided on review comments, call `/review-search` to find all REVIEW
   comments in the codebase. **DON'T** just use the find method, you need to use the command.

2. For each comment found, **ALWAYS** look at the surrounding and/or related code to fully
   understand the context. If you aren't sure about a comment, **ALWAYS** use `AskUserQuestion`
   tool to clarify. You **MUST** fully understand the context before taking any action, using the
   context understanding checklist.

3. **ALWAYS** create an action plan:
   * Build internal TODO list from review comments
   * Create a new empty jj change on which to make the fixes
   * Update project doc Tasks section with identified tasks
   * Prioritize tasks based on dependencies

4. Execute tasks systematically:
   * Address each task one by one
   * Always make sure you fully understand the context before making changes
   * Remove associated review comments after completion
   * Update project doc Tasks section progress as you go

5. Final verification:
   * Search again for any remaining review comments
   * Ensure project doc reflects all completed work
   * Run tests, formatting, and linting to fix any issues
   * Commit the jj change with a clear message summarizing the fixes

## Important rules

* **NEVER** replace REVIEW comments with "// Note:" explanations or similar. Always report them to me if you
  believe they are unnecessary, and keep the REVIEW comment in the code.

* **NEVER** Take decision of not taking action on a comment that was an action item on the premise
  that you think it is not needed. If you want to pushback on a comment, you must communicate with
  me. You can fix the rest of the comments, but then clearly tell me that you did not address the
  comment and why you think it is not needed. I will then decide if it is needed or not.
