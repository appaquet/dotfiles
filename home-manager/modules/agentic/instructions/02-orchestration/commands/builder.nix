{
  nixantic.sources.orchestration.commands."builder" =
    { scope }:
    {
      description = "Activate builder mode";
      arguments = [ { label = "Task"; } ];
      harnesses = [
        "claude"
        "pi"
      ];

      onlyInjectBlockReferences = [ ];

      content = ''
        ${scope.blocks."builder-prompt".body}

        🔨 Builder mode activated.

        STOP. Wait for the next user message.
      '';
    };
}
