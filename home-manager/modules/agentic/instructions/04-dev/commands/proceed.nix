{
  nixantic.sources.development-workflow.commands."proceed" =
    { scope }:
    {
      description = "Proceed with current workflow";

      content = ''
        Goal: proceed with the current workflow.

        ## Instructions

        1. 🔳 Breakdown work and create tasks as needed using `${scope.harness.tools.taskCreate}`

        2. 🔳 Execute tasks one by one

        ${scope.blocks."engagement-gate".release}
      '';
    };
}
