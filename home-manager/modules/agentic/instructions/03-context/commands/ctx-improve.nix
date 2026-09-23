{
  nixantic.sources.context-management.commands."ctx-improve" =
    { scope }:
    {
      description = "Resolve context gaps through research and targeted clarification";

      arguments = [ { label = "Focus"; } ];

      effort = "xhigh";

      content = ''
        Goal: resolve context gaps for the next planned step using ${scope.blocks.context-understanding.reference}.

        ## Instructions

        1. Ensure ${scope.skills."project-docs".reference} loaded.

        2. 🔳 Report current understanding
           * Using ${scope.blocks.context-understanding.reference}
           * If 10/10 understanding, stop and report

        3. 🔳 Research context
           * Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation
           * Search web for unfamiliar or potential outdated info
           * Track uncertainties that block the next planned step as sub-tasks 🔳.

        4. 🔳 Ask about remaining decisions, if any
           * Follow ${scope.blocks.clarification-procedure.reference}.
           * Record questions and answers following ${scope.skills."project-docs".reference}.
           * Return to step 3 only when an answer requires further research.

        5. 🔳 Update project files
           * Flush any remaining accumulated questions, answers, investigation outcomes and decisions to the relevant project files, following ${
             scope.skills."project-docs".reference
           }. If unclear, ask user.

        6. **STOP**: User decides next action.
      '';
    };
}
