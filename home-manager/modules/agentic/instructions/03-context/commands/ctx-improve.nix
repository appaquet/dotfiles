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
           - Use ${scope.blocks.deep-thinking.reference}
           - Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation
           - Search web for unfamiliar or potential oudated info
           - Add sub-task 🔳 to prevent forgetting uncertainties, work them out until full understanding

        3. 🔳 Ask clarifying questions
           - Interview me relentlessly, using `AskUserQuestion`, about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer. Any questions you could answer yourself through research should be researched first. If still unsure, give me as much context as possible in questions.
           - Go back to step 2 after each answers that require further analysis. Should add more tasks 🔳 to track progress.

        4. 🔳 Update project & phases docs
           - If planned into project docs. If in-memory, don't need to write. If unclear, ask user.

        5. **STOP**: User decides next action.
      '';
    };
}
