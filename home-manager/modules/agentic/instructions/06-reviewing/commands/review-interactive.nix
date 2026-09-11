{
  nixantic.sources.review-workflow.commands."review-interactive" = { scope }: {
    description = "Interactive review flow, investigating each feedback/comment with sub-agent and collecting into phase documentation";

    arguments = [
      {
        label = "Feedback";
        hint = "[review feedback/comments]";
      }
    ];

    content = ''
      Goal: Interactively review feedback/comments, investigate each with sub-agent, and collect into phase documentation. 
            User then call planning for those review items after he deemed collection is complete.

      Before reading, interpreting, or updating project or phase documents, load ${
        scope.skills."project-docs".reference
      }.

      ## Instructions

      1. 🔳 Prepare the review phase
         - If no committed project files exist, confirm with the user and create the project
           (symlink + docs) following the project files rules.
         - Create a new phase in project documentation for this review session.
           Should be a sub-phase of latest phase that we worked on. E.g. phase 1 -> phase 1a.
         - If no review feedback/comments were provided: STOP and tell the user the review phase is
           ready and you are awaiting for reviews.

      2. For each feedback/comment, launch a ${
        scope.agents."junior-dev".reference
      } in background to explore/investigate the feedback.
         Collect the results into questions/investigations section. 
         If directly actionable without further planning, add to tasks section.
         If planning is required, note it and tell user about it. 
         NEVER FIX them directly, we are only collecting feedback and investigations.
         Collect all your questions for when I'll trigger a planning workflow. Don't ask them as we go.
         Do NOT launch review agents for feedback. We're just collecting evidence, not reviewing anything yet.

      3. When user calls planning flow for those items and all feedback/comments are investigated
         and collected, review the combined project-document diff and commit it once following the
         project-document version-control instructions. 

      ${scope.forHarness {
        claude = "NEVER engage the native plan mode `EnterPlanMode`";
        default = "";
      }}
    '';
  };

}
