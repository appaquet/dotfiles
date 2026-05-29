{
  nixantic.sources.orchestration.commands."orchestrator" =
    { scope }:
    {
      description = "Activate orchestrator mode";
      harnesses = [ "claude" ];

      content = scope.blocks."orchestration-prompt".body;
    };
}
