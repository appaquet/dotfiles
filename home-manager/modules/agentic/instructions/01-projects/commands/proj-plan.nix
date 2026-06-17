{
  # Keep in sync with ctx-plan.
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
        1. Ensure ${scope.skills."proj-writing".reference} loaded.
           - If project files above empty, STOP, and tell user. If in-memory planning required, use ${
             scope.commands."ctx-plan".reference
           } instead.

        2. 🔳 Ensure context loaded, goal clear, task defined
           - Use ${scope.commands."proj-load".reference} if not already loaded.
           - Clarify via `AskUserQuestion` if empty or unclear.

        3. 🔳 Research, clarify and plan
           ${scope.blocks."plan-procedure".embed}

        4. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}. If understanding < 10/10, suggest ${
          scope.commands."ctx-improve".reference
        }

        5. 🔳 Write plan to docs 
           - Need to use ${
             scope.skills."proj-writing".reference
           }, use project & phase docs rules and structure

        6. ${scope.blocks."engagement-gate".gate}

        ${scope.forHarness {
          claude = "NEVER engage the native plan mode `EnterPlanMode`";
          default = "";
        }}
      '';
    };
}
