{
  # Keep in sync with proj-plan.
  nixantic.sources.context-management.commands."ctx-plan" =
    { scope }:
    {
      description = "Create high-level development plan and write to ad-hoc/temp project/phases docs";
      argumentHint = "[task-description]";

      effort = "xhigh";

      content = ''
        Goal: build a full, ad hoc plan for the task at hand: $ARGUMENTS

        ## State

        ${scope.blocks."project-files".embed}

        If committed / non ad-hoc project files are listed, STOP and report. This command only creates ad hoc project files.

        ## Instructions
        1. Ensure ${scope.skills."project-docs".reference} loaded.

        2. 🔳 Create the ad hoc folder
           - From the workspace root, run `agentic-proj-create-adhoc` with no arguments.
           - Create normal `00-<project>.md` and `01-<phase>.md` files in the directory reported by `agentic-proj-docs`.

        3. 🔳 Ensure context loaded, goal clear, task defined
           - ${scope.harness.prose.questions.request} if empty or unclear.

        4. 🔳 Research, clarify and plan
           ${scope.blocks."plan-procedure".embed}

        5. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}. If understanding < 10/10, suggest ${
          scope.commands."ctx-improve".reference
        }

        6. 🔳 Write plan to docs
           - Using ${scope.skills."project-docs".reference}, use project & phase docs rules and structure

        7. ${scope.blocks."engagement-gate".gate}

        ${scope.forHarness {
          claude = "NEVER engage the native plan mode `EnterPlanMode`";
          default = "";
        }}
      '';
    };
}
