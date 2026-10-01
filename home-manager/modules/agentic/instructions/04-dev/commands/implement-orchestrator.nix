{
  nixantic.sources.development-workflow.commands."implement-orchestrator" =
    { scope }:
    {
      description = "Implement tasks from the approved plan in orchestrator mode";

      arguments = [ { label = "Task"; } ];

      effort = "xhigh";

      agent = scope.forHarness {
        opencode = "orchestrator"; # opencode selects the mode through its agents
        default = null;
      };

      content = ''
        ${scope.blocks."orchestration-prompt".body}

        Goal: proceed to implementation of the plan/task at hand

        ${scope.blocks."implement-workflow".body}
      '';
    };
}
