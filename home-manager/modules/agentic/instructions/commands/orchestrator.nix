{ scope }:
{
  description = "Activate orchestrator mode";
  harnesses = [ "claude" ];

  content = scope.blocks.orchestrator-mode.body;
}
