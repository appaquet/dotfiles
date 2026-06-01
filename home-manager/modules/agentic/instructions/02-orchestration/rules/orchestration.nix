{
  nixantic.sources.orchestration.instructions."rules/orchestration" =
    { scope }:
    {
      heading = "Sub-agents workflows";
      content = ''
        ${scope.blocks."sub-agents-workflows".embed}
      '';
    };
}
