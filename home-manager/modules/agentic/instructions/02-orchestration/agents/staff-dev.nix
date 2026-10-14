{
  # IMPORTANT: Before changing scope of this developer, check `sub-agents-workflow.nix` dimensions comment, keep in sync.
  nixantic.sources.orchestration.agents."staff-dev" =
    { scope }:
    {
      description = "Staff developer for cross-system architecture/implementation, systemic diagnosis, or critical/high-blast-radius technical decisions within supplied product direction.";
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
          effort = "high";
        };
        opencode = "openai/gpt-5.6-sol";
        pi = "scoped/staff";
      };

      content = ''
        ${scope.blocks."developer-execution".embed}
      '';
    };
}
