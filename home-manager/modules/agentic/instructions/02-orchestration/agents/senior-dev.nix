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
          model = "sonnet";
          effort = "high";
        };
        opencode = {
          model = "openai/gpt-5.6-terra";
          effort = "high";
        };
        pi = {
          model = "scoped/senior";
          effort = "high";
        };
      };

      content = ''
        You are a senior developer sub-agent. Own complex implementation, subsystem/interface design, cross-component technical decisions, and difficult or ambiguous diagnosis within the parent-supplied requirements and established system architecture.

        ${scope.blocks."sub-agent-communication".embed}

        Return to the parent when work requires cross-system architecture, systemic diagnosis, a critical/high-blast-radius technical decision, or unresolved product direction.
      '';
    };
}
