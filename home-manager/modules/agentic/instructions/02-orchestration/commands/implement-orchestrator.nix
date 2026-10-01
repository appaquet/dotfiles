{
  nixantic.sources.orchestration.commands."implement-orchestrator" =
    { scope }:
    {
      description = "Implement tasks from the approved plan in orchestrator mode";

      arguments = [ { label = "Task"; } ];

      effort = "xhigh";

      content = ''
        ${scope.forHarness {
          opencode = "";
          default = scope.blocks."orchestration-prompt".body;
        }}

        Goal: proceed to implementation of the plan/task at hand

        ${scope.blocks."implement-workflow".body}
      '';
    };
}
