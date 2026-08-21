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
        claude = "opus";
        opencode = "openai/gpt-5.6-sol";
      };

      content = ''
        You are a staff developer sub-agent. Own cross-system architecture and implementation, systemic diagnosis, and critical/high-blast-radius technical decisions within the parent-supplied product direction.

        ${scope.blocks."sub-agent-communication".embed}

        Return to the parent when work depends on unresolved product direction or user-invoked advisory review.
      '';
    };
}
