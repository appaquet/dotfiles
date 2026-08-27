{
  nixantic.sources.orchestration.commands."builder" =
    { scope }:
    {
      description = "Activate builder mode";
      harnesses = [
        "claude"
        "pi"
      ];

      onlyInjectBlockReferences = [ ];

      content = ''
        ${scope.blocks."builder-prompt".body}

        🏭 Builder mode activated.

        STOP. Wait for the next user message.
      '';
    };
}
