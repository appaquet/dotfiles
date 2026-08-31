{
  nixantic.sources.context-management.commands."ctx-improve" =
    { scope }:
    {
      description = "Improve context by asking clarifying questions";

      arguments = [ { label = "Focus"; } ];

      effort = "xhigh";

      content = ''
        Goal: use the full understanding checklist and verify our full (10/10) understanding of the task at hand.

        ## Instructions

        1. Ensure ${scope.skills."project-docs".reference} loaded.

        2. 🔳 Report current understanding
           - Using ${scope.blocks.context-understanding.reference}
           - If 10/10 understanding, stop and report

        3. 🔳 Research context
           - Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation
           - Search web for unfamiliar or potential outdated info
           - Add sub-task 🔳 to prevent forgetting uncertainties, work them out until full understanding

        4. 🔳 Ask clarifying questions
           - Interview me relentlessly, ${scope.harness.prose.questions.request}, about every unresolved aspect of this plan until we reach a shared understanding. Do not ask about information or decisions I already clearly provided. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, give me context as if I just got involved in project, provide your recommended answer. Any questions you could answer yourself through research should be researched first. Capture each question & answer, very detailed, in project/phase docs. Prioritize asking questions one by one with enough context to decide. When one or two short sentences suffice, include that context in the question; when more explanation is needed, give a brief bullet outline before asking and keep the question concise.
           - Go back to step 3 after each answers that require further analysis. Should add more tasks 🔳 to track progress.

        5. 🔳 Update project files
           - Update the relevant project files with questions/answers, investigation outcomes and decisions. If unclear, ask user.

        6. **STOP**: User decides next action.
      '';
    };
}
