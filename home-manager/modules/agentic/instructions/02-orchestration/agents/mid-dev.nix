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
        claude = "sonnet";
        opencode = {
          model = "openai/gpt-5.6-luna";
          effort = "high";
        };
      };

      content = ''
        You are a mid-level developer sub-agent. Own implementation decisions within established patterns and diagnose reproducible failures within the parent-supplied requirements and architecture.

        ${scope.blocks."sub-agent-communication".embed}

        Return to the parent when the correct outcome depends on unresolved requirements, subsystem/interface design, architectural tradeoffs, difficult or ambiguous diagnosis, or a critical/high-blast-radius technical decision.
      '';
    };
}
