{
  # Keep in sync with `ctx-plan`
  nixantic.sources.projects.commands."proj-plan" =
    { scope }:
    {
      description = "Create high-level development plan and write to project/phases docs";
      argumentHint = "[task-description]";

      effort = "xhigh";

      content = ''
        Goal: build a full plan for the task at hand: $ARGUMENTS

        ## State

        ${scope.blocks."project-files".embed}

        ## Instructions
        1. Ensure `proj-editing` skill loaded.
           - If project files above empty, STOP, and tell user. If in-memory planning required, use `ctx-plan` instead.

        2. 🔳 Ensure context loaded, task define. 
           - Use `proj-load` if not already loaded.
           - Clarify via `AskUserQuestion` if empty or unclear.

        3. 🔳 Research, clarify and plan
           ${scope.blocks."plan-procedure".embed}

        4. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}. If understanding < 10/10, suggest `ctx-improve`

        5. 🔳 Write plan to docs 
           - Need to use `proj-editing` skill, use project & phase docs rules and structure

        6. **STOP**: User will decide next steps

        ${scope.forHarness {
          claude = "NEVER engage the native plan mode `EnterPlanMode`";
          default = "";
        }}
      '';
    };
}
