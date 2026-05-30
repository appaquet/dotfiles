{
  nixantic.sources.context-management.commands."ctx-plan" =
    { scope }:
    {
      description = "Load repository context and create high-level development plans";

      argumentHint = "[task-description]";

      effort = "xhigh";

      content = ''
        Goal: build a full plan for the task at hand: $ARGUMENTS

        Project files: !`claude-proj-docs`
        If no project files, assume we are working in memory only and skip any steps related to project files

        ${scope.forHarness {
          claude = "NEVER engage the native plan mode `EnterPlanMode`";
          default = "";
        }}

        ## Instructions
        1. Ensure `proj-editing` skill loaded.

        2. 🔳 Ensure context loaded, task define. 
           - Use `ctx-load` if not done.
           - Clarify via `AskUserQuestion` if empty or unclear.

        3. 🔳 Research and clarify
           - Use ${scope.blocks.deep-thinking.reference}
           - Use ${scope.blocks.sub-agents-workflows.reference} for exploration, research and investigation
           - Search web for unfamiliar or potential oudated info
           - Add sub-task 🔳 to prevent forgetting uncertainties, work them out until full understanding

           - Interview me relentlessly, using `AskUserQuestion`, about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

           - List/understand/ask for requirements and acceptance criteria.
           - Define ACs per task. Each is specific verifiable condition maps to test assertion.
           - Note all planning decisions and investigation outcomes.
           - Select agent that will accomplish each task (junior, senior or staff).
           - Plan testing using ${scope.blocks.testing-principles.reference}

        4. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}. If understanding < 10/10, suggest `ctx-improve`

        5. 🔳 Write plan to docs (or memory if none) 
           - Need to use `proj-editing` skill, use project & phase docs rules and structure
           - Break into logical phases
           - Identify key files and components
           - Develop one component at the time, writing its test before if possible, and make it passes before moving on to next step. If user validation needed, add it as a step in the plan
           - Consider dependencies and challenges
           - It is crucial to include testing strategy in plan so you are autonomous

        6. **STOP**: User will decide next steps
      '';
    };
}
