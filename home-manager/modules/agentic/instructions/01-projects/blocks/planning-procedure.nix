{
  nixantic.sources.projects.blocks."plan-procedure" =
    { scope }:
    {
      content = ''
        * Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation

        * Use ${scope.blocks.context-understanding.reference} to improve understanding

        * Search web for unfamiliar or potential outdated info
        * Track uncertainties that block the next planned step as sub-tasks 🔳.

        * Follow ${scope.blocks.clarification-procedure.reference} to resolve gaps before asking questions.

        * Record questions and answers following ${scope.skills."project-docs".reference}.

        * List/understand/ask for requirements and acceptance criteria.
        * Note all planning decisions, questions and answers, investigation outcomes, key decisions, etc.

        * Break into logical phases.
        * Identify key files and components
        * Consider dependencies and challenges

        * Breakdown in tasks, with ACs, dependencies, defined enough for any engineers to pick up and understand context/decisions/scope. You will NOT be the one implementing the tasks, so you must provide enough context and information for any engineer to pick up and implement them.
        * Select the agent for each task using ${scope.blocks.sub-agent-selection.reference}
        * Include validation in tasks for autonomous iteration using ${scope.blocks.testing-principles.reference}
      '';
    };
}
