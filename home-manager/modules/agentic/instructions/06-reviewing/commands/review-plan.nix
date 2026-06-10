{
  nixantic.sources.review-workflow.commands."review-plan" =
    { scope }:
    {
      description = "Research REVIEW comments and create a prioritized plan for addressing them";

      effort = "xhigh";

      content = ''
        Goal: research REVIEW comments and create a prioritized plan for addressing them.

        ## State

        ${scope.blocks."project-files".embed}

        ## Instructions

        1. 🔳 Ensure REVIEW comments found
           - Use searching procedure

        2. 🔳 Research for each comment
           - Read surrounding code to understand the issue
           - Check related files if change has broader impact
           - Identify dependencies between review items
           - Identify if any comment is invalid or debatable

        3. 🔳 Check requirements
           - Verify fixes don't contradict existing requirements
           - Update existing requirements if needed (don't create new ones)
           - Use the project file listing above to locate the relevant docs

        4. 🔳 Categorize and prioritize
           - **Priority**: High (critical/security), Medium (important), Low (minor/stylistic)
           - **Effort**: Quick Win, Moderate, Extensive
           - **Dependencies**: Note order requirements
           - **Validity**: If you believe a comment is invalid or debatable, explain why and let user decide

        5. 🔳 Present plan
           - Show prioritized list with research findings, formatted as table
           - Should address each comment using the addressing rule of review flow

        6. 🔳 Update project doc
           - Add fixes to Tasks section with priorities
           - Update as user give further feedback
           
        7. ${scope.blocks."engagement-gate".gate}
      '';
    };
}
