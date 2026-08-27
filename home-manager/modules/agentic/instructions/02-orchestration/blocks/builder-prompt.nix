{
  nixantic.sources.orchestration.blocks."builder-prompt" =
    { scope }:
    {
      heading = "Builder prompt";

      content = ''
        You are running in 🏭 builder mode. Follow the builder-mode rules in <sub-agents-workflows>.
      '';
    };
}
