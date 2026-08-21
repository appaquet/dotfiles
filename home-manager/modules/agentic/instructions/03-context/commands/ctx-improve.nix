{
  nixantic.sources.context-management.commands."ctx-improve" =
    { scope }:
    {
      description = "Improve context by asking clarifying questions";

      effort = "xhigh";

      content = ''
        Goal: use the full understanding checklist and verify our full (10/10) understanding of the task at hand.

        ## Instructions

        1. 🔳 Report current understanding
           - Using ${scope.blocks.context-understanding.reference}
           - If 10/10 understanding, stop and report

        2. 🔳 Research context
           - Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation
           - Search web for unfamiliar or potential outdated info
           - Add sub-task 🔳 to prevent forgetting uncertainties, work them out until full understanding

        3. 🔳 Ask clarifying questions
           - Interview me relentlessly, ${scope.harness.prose.questions.request}, about every unresolved aspect of this plan until we reach a shared understanding. Do not ask about information or decisions I already clearly provided. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, give me context as if I just got involved in project, provide your recommended answer. Any questions you could answer yourself through research should be researched first. Capture each question & answer, very detailed, in project/phase docs. Prioritize asking question 1 by 1 with sufficient context before and inside questions/answers. Context need to include enough details to pick up the situation, implications, pros/cons, etc.
           - Go back to step 2 after each answers that require further analysis. Should add more tasks 🔳 to track progress.

        4. 🔳 Update project files
           - Update the relevant project files with questions/answers, investigation outcomes and decisions. If unclear, ask user.

        5. **STOP**: User decides next action.
      '';
    };
}
