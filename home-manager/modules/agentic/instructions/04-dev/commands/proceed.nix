{
  nixantic.sources.development-workflow.commands."proceed" =
    { scope }:
    {
      description = "Proceed with current workflow";

      content = ''
        Goal: proceed with the current workflow. Clears any pending "Await /proceed" gate tasks and lets the calling command continue.

        After instructions & tasks loaded, you are free to 🚀 Engage thrusters

        ## Instructions

        1. 🔳 Clear gate tasks
           - Check `TaskList` for any "Await /proceed" tasks
           - Mark them completed
           - The calling workflow continues from where it left off

        2. 🔳 Breakdown and create tasks as needed using `${scope.harness.tools.taskCreate}`

        3. 🔳 Execute tasks one by one
      '';
    };
}
