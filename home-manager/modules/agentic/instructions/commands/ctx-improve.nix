{ scope }:
{
  description = "Improve context by asking clarifying questions";

  effort = "xhigh";

  content = ''
    Goal: use the full understanding checklist and verify our full (10/10) understanding of the task at hand.

    ## Instructions

    1. 🔳 Check current understanding
       - If 10/10 understanding, stop and report
       - Otherwise, give your understanding on 10

    2. 🔳 Research context
       - Use ${scope.blocks.deep-thinking.reference}
       - Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation
       - Search web for unfamiliar or potential oudated info
       - For any uncertainty, add sub-task to prevent forgetting to resolve it.

    3. 🔳 Ask clarifying questions
       - Interview me relentlessly, using `AskUserQuestion`, about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.
       - Go back to step 2 after each answers that require further analysis. Should add more tasks 🔳 to track progress.

    4. 🔳 Update project & phases docs

    5. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}.

    6. **STOP**: User decides next action.
  '';
}
