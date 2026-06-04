{
  nixantic.sources.development-workflow.commands."proceed" =
    { scope }:
    {
      description = "Proceed with current workflow";

      content = ''
        Goal: proceed with the current workflow.

        After instructions & tasks loaded, 🚀 Engage thrusters

        ## Instructions

        1. 🔳 Breakdown work and create tasks as needed using `${scope.harness.tools.taskCreate}`

        2. 🔳 Execute tasks one by one
      '';
    };
}
