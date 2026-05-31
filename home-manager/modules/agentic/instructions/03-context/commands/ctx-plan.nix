{
  # Keep in sync with `proj-plan`
  nixantic.sources.context-management.commands."ctx-plan" =
    { scope }:
    {
      description = "Create high-level development/execution plan in memory";
      argumentHint = "[task-description]";

      effort = "xhigh";

      content = ''
        Goal: build a full plan for the task at hand, in memory/context: $ARGUMENTS

        Project files: !`claude-proj-docs`

        ${scope.forHarness {
          claude = "NEVER engage the native plan mode `EnterPlanMode`";
          default = "";
        }}

        ## Instructions
        1. If project files exist, confirm with user if they want to write plan to project docs. If yes, STOP, and tell user to run `proj-plan`.

        2. 🔳 Ensure task define. 
           - Clarify via `AskUserQuestion` if empty or unclear.

        3. 🔳 Research, clarify and plan
           ${scope.blocks."plan-procedure".embed}

        4. 🔳 Report your understanding using ${scope.blocks.context-understanding.reference}. If understanding < 10/10, suggest `ctx-improve`

        5. 🔳 Expose plan to user without writing to docs.
           - Use `proj-editing` skill for structure, but don't actually write to docs.

        6. **STOP**: User will decide next steps
      '';
    };
}
