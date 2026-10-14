{
  # IMPORTANT: Before changing scope of this developer, check `sub-agents-workflow.nix` dimensions comment, keep in sync.
  nixantic.sources.orchestration.agents."mid-dev" =
    { scope }:
    {
      description = "Mid-level developer for well-scoped work within settled requirements and architecture: established-pattern implementation, test iteration, and reproducible diagnosis.";
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
          model = "sonnet";
          effort = "medium";
        };
        opencode = {
          model = "openai/gpt-5.6-luna";
          effort = "high";
        };
        pi = {
          model = "scoped/mid";
        };
      };

      content = ''
        ${scope.blocks."developer-execution".embed}
      '';
    };
}
