{
  # Keep in sync with proj-plan.
  nixantic.sources.context-management.commands."ctx-plan" =
    { scope }:
    {
      description = "Create high-level development/execution plan in memory";
      argumentHint = "[task-description]";

      effort = "xhigh";

      content = ''
        Goal: build a full plan for the task at hand, in memory/context: $ARGUMENTS

        ## State
        ${scope.blocks."project-files".embed}

        ${scope.forHarness {
          claude = "NEVER engage the native plan mode `EnterPlanMode`";
          default = "";
        }}

        ## Instructions
        1. If project files listed above show, confirm with user if they want to write plan to project docs. If yes, STOP, and tell user to run ${
          scope.commands."proj-plan".reference
        }.

        2. 🔳 Ensure context loaded, goal clear, task defined
           - Clarify via `AskUserQuestion` if empty or unclear.

        3. 🔳 Research, clarify and plan
           ${scope.blocks."plan-procedure".embed}

        4. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}. If understanding < 10/10, suggest ${
          scope.commands."ctx-improve".reference
        }

        5. 🔳 Expose plan to user without writing to docs.
           - Use the project doc structure and rules as a template, but keep the plan in memory and do not write docs.

        6. ${scope.blocks."engagement-gate".gate}
      '';
    };
}
