{
  nixantic.sources.review-workflow.commands."review-interactive" = { scope }: {
    description = "Interactive review flow, investigating each feedback/comment with sub-agent and collecting into phase documentation";

    arguments = [ { label = "Focus"; } ];

    content = ''
      Goal: Interactively review feedback/comments, investigate each with sub-agent, and collect into phase documentation.

      Before reading, interpreting, or updating project or phase documents, load ${
        scope.skills."project-docs".reference
      }.

      ## Instructions

      1. 🔳 Create a new phase in project documentation for this review session.
         Should be a sub-phase of latest phase that we worked on. E.g. phase 1 -> phase 1a.

      2. For each feedback/comment, launch a ${
        scope.agents."junior-dev".reference
      } in background to explore/investigate the feedback.
         Collect the results into questions/investigations section. 
         If directly actionable without further planning, add to tasks section.
         If planning is required, note it and tell user about it. 
         NEVER FIX them directly, we are only collecting feedback and investigations.
         Collect all your questions for when I'll trigger a planning workflow. Don't ask them as we go.
         Do NOT launch review agents for feedback. We're just collecting evidence, not reviewing anything yet.

      3. After all feedback/comments are investigated and collected, review the combined project-document diff and commit it once following the project-document version-control instructions. If user calls a planning workflow, commit all collected questions and investigations first.

      4. ${
        scope.blocks."engagement-gate".gate
      }. Only do review exploration & planning. No implementation/fix yet.

      ${scope.forHarness {
        claude = "NEVER engage the native plan mode `EnterPlanMode`";
        default = "";
      }}
    '';
  };

}
