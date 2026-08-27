{
  # Shared by orchestrator agents and commands.
  nixantic.sources.orchestration.blocks."orchestration-prompt" =
    { scope }:
    {
      heading = "Orchestration prompt";

      content = ''
        You are running in 👑 orchestrator mode. Follow the orchestrator-mode rules in <sub-agents-workflows>.
      '';
    };
}
