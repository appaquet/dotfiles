{
  nixantic.sources.projects.commands."proj-brief" =
    { scope }:
    {
      description = "Brief the user on project status: phases, progress and pending questions";
      arguments = [ { label = "Context"; } ];
      effort = "medium";
      asSkill = {
        opencode = true;
        pi = true;
      };
      content = ''
        Goal: brief the user on the status of the project loaded in context. The user is context-switching, so write for someone who remembers nothing.

        ## Instructions

        1. Use the project and phase docs already in context, don't re-read them
           * If no project is loaded, STOP and tell the user to run ${
             scope.commands."proj-load".reference
           } first
           * Read a doc only when a needed piece is missing from context (e.g. a phase's unchecked questions)

        2. Output the briefing below, in this order. Keep it to about one page and plain language. Explain a phase, task or requirement by what it covers; the number or code is only a navigation aid
           * Header: project name, date, phases done out of total, when the docs were last saved when known
           * Goal: one line
           * Where we are: the active phase, its task progress, what is done and what is missing, from the checkpoint and tasks. When several phases are in progress, cover each briefly
           * Phases: one row per phase with number, name, status marker (task count for the active one) and what it covers
           * Needs your input (N): every unchecked question from the project and phase docs. Give each its phase, why it matters (context), whether it blocks work, and a recommendation when the docs have one. Omit answered questions
           * Next: the immediate next step and what it unblocks
           * Add an inbox count or a blockers line only when non-empty

        Output template:

        ```
        ## <project> · <date> · <done>/<total> phases done
        Goal: <one line>

        ### Where we are
        <active phase, progress, done vs missing, next step>

        ### Phases
        | #  | Phase | Status | What it covers |
        |----|-------|--------|----------------|
        | 01 | <name> | ✅ done | <short> |
        | 02 | <name> | 🔄 3/5 tasks | <short> |
        | 03 | <name> | ⬜ not started | <short> |

        ### Needs your input (<N>)
        1. **<question>** (<phase>, blocks: <what> | not blocking)
           Context: <why it matters>
           Recommend: <answer, when known>

        ### Next
        <next step> → <what it unblocks>
        ```
      '';
    };
}
