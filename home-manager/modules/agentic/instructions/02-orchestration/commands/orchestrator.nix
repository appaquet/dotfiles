{
  nixantic.sources.orchestration.commands."orchestrator" =
    { scope }:
    {
      description = "Activate orchestrator mode";
      harnesses = [
        "claude"
        "pi"
      ];

      onlyInjectBlockReferences = [ ];

      content = ''
        ${scope.blocks."orchestration-prompt".body}

        👑 Orchestrator mode activated.

        STOP. Wait for the next user message.
      '';
    };
}
