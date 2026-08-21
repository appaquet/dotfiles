{
  nixantic.sources.harnesses.instructions."pi-workflows" =
    { scope }:
    {
      harnesses = [ "pi" ];
      role = "rule";
      heading = "Pi workflow capabilities";
      content = ''
        Use `${scope.harness.tools.agentLaunch}` to launch a configured sub-agent. Retrieve a completed sub-agent result with `${scope.harness.tools.agentResult}`. Send follow-up guidance to a running sub-agent with `${scope.harness.tools.agentSteer}`.

        ${scope.harness.prose.tasks.workflow}

        Sub-agent and task capabilities are independently configured. Do not assume that selecting one installs, activates, or invokes the other.
      '';
    };
}
