{
  nixantic.sources.review-workflow.commands."review-plan" =
    { scope }:
    {
      description = "Research REVIEW comments, present plan, then fix after /implement";

      effort = "xhigh";

      content = ''
        Goal: research REVIEW comments, present prioritized plan, await for implement command and fix.

        REVIEW comments are my way of communicating issues or improvements to act on right away.
        They aren't left for future consideration nor to be ignored.

        ## Instructions

        ### Phase 1: Plan

        1. 🔳 Ensure REVIEW comments found
           - Follow the searching procedure from the reviewing doc unless we just searched
           - Never roll your own search

        2. 🔳 Research each comment
           - Read surrounding code to understand the issue
           - Check related files if change has broader impact
           - Identify dependencies between review items
           - Identify if any comment is invalid or debatable

        3. 🔳 Categorize and prioritize
           - **Priority**: High (critical/security), Medium (important), Low (minor/stylistic)
           - **Effort**: Quick Win, Moderate, Extensive
           - **Dependencies**: Note order requirements
           - **Validity**: If you believe a comment is invalid or debatable, explain why and let user decide

        4. 🔳 Check requirements
           - Verify fixes don't contradict existing requirements
           - Update existing requirements if needed (don't create new ones)

        5. 🔳 Update project doc
           - Add fixes to Tasks section with priorities

        6. 🔳 Present plan
           - Show prioritized list with research findings

        7. **GATE**: Wait for `/implement`

        ### Phase 2: Execute

        After `/implement` is called, follow its workflow with these review-specific additions:

        8. 🔳 Create tasks from REVIEW comments
            - One `${scope.harness.tools.taskCreate}` per comment: "Fix: [file:line]"

        9. 🔳 For each fix
           - Remove REVIEW comment after addressing it
           - Never replace with "// Note:" explanations

        10. 🔳 Verify completion
            - Search for remaining REVIEW comments
            - Search for orphaned removals (comments removed without fix)

        ## Important Rules

        * **NEVER** replace REVIEW comments with "// Note:" explanations. Report to user if you
          believe they are unnecessary, keep the comment, and let user decide.

        * **NEVER** skip a comment. If you want to pushback, fix other comments first, then clearly
          state which you didn't address and why. User decides.
      '';
    };
}
