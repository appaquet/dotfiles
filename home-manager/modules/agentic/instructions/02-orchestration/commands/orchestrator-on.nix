{
  nixantic.sources.orchestration.commands."orchestrator-on" =
    { scope }:
    {
      description = "Activate orchestrator mode";
      harnesses = [ "claude" ];

      content = ''
        ${scope.blocks."orchestration-prompt".body}

        STOP. Don't do anything until I tell you to.
      '';
    };
}
