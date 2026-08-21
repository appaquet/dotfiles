{
  # Keep in sync with ctx-plan.
  nixantic.sources.projects.commands."proj-plan" =
    { scope }:
    {
      description = "Create high-level development plan and write to committed project/phases docs";
      argumentHint = "[task-description]";

      effort = "xhigh";

      content = ''
        Goal: build a full plan for the task at hand: $ARGUMENTS

        ## State

        ${scope.blocks."project-files".embed}

        ${scope.forHarness {
          pi = "Run `date +%Y/%m/%d` with the shell tool and use its stdout as the current date.";
          default = "Current date: !`date +%Y/%m/%d`";
        }}

        If ad-hoc project files are listed, stop and report. This command creates committed project files.

        ## Instructions
        1. Ensure ${scope.skills."proj-writing".reference} loaded.

        2. 🔳 Ensure context loaded, goal clear, task defined
           - ${scope.harness.prose.questions.request} if the goal or task is empty or unclear.

        3. 🔳 Find or create project files
           - If no committed project files, confirm with user that a new project should be created and a suggestion of name based on goal or branch name. On confirmation, create project symlink, initial project doc structure following project files rules.
           - If committed project files exist, check if goal aligned with project and can be added as phase. Otherwise, confirm with user and propose new project to be created.
           - If committed project files exist and goal is aligned, confirm phase name with user.
           - If new project, follow version control rules for symlink commit & doc commits.

        4. 🔳 Research, clarify and plan
            ${scope.blocks."plan-procedure".embed}

        5. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}. If understanding < 10/10, suggest ${
          scope.commands."ctx-improve".reference
        }

        6. 🔳 Write plan to docs
           - Use ${scope.skills."proj-writing".reference} and the project and phase doc rules.

        7. ${scope.blocks."engagement-gate".gate}

        ${scope.forHarness {
          claude = "NEVER engage the native plan mode `EnterPlanMode`";
          default = "";
        }}
      '';
    };
}
