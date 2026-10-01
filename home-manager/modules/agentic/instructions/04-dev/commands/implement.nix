{
  nixantic.sources.development-workflow.commands."implement" =
    { scope }:
    {
      description = "Implement tasks from the approved plan";

      arguments = [ { label = "Task"; } ];

      effort = "xhigh";

      agent = scope.forHarness {
        opencode = "build"; # opencode selects the mode through its agents
        default = null;
      };

      content = ''
        ${scope.blocks."builder-prompt".body}

        Goal: proceed to implementation of the plan/task at hand

        ${scope.blocks."implement-workflow".body}
      '';
    };
}
