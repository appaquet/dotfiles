{
  # IMPORTANT: Before changing scope of this developer, check `sub-agents-workflow.nix` dimensions comment, keep in sync.
  nixantic.sources.orchestration.agents."senior-dev" =
    { scope }:
    {
      description = "Senior developer for complex implementation, subsystem/interface design, cross-component tradeoffs, or difficult/ambiguous diagnosis within established system architecture.";
      permission = {
        opencode = {
          task = "deny";
        };
        claude = {
          disallowedTools = [ "Agent" ];
        };
        pi = {
          allowedSubagents = false;
        };
      };

      model = {
        claude = {
          model = "opus";
        };
        opencode = {
          model = "openai/gpt-5.6-terra";
          effort = "high";
        };
        pi = {
          model = "scoped/senior";
        };
      };

      content = ''
        ${scope.blocks."developer-execution".embed}
      '';
    };
}
