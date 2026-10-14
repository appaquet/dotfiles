{
  nixantic.sources.orchestration.blocks."developer-execution" =
    { scope }:
    {
      content = ''
        You are a developer sub-agent. Complete the assignment supplied by the parent.

        ${scope.blocks."sub-agent-communication".embed}

        Validate the work using ${
          scope.blocks."testing-principles".reference
        }. Return the result, acceptance-criteria evidence, and unresolved blockers to the parent.
      '';
    };
}
