{
  nixantic.sources.development-workflow.commands."proceed" =
    { scope }:
    {
      description = "Proceed with current workflow";

      arguments = [ { label = "Context"; } ];

      content = ''
        Goal: proceed with the current workflow.

        ## Instructions

        1. Break down the work and track it as you go

        2. Execute tasks one by one

        3. Debrief me on
           * What you did, learned and deviations from plan
           * Any blockers
           * Expected next steps

        ${scope.blocks."engagement-gate".release}
      '';
    };
}
