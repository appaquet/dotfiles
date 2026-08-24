{
  # IMPORTANT: Before changing scope of this developer, check `sub-agents-workflow.nix` dimensions comment, keep in sync.
  nixantic.sources.orchestration.agents."principal-dev" =
    { scope }:
    {
      description = "Explicit-user-invoked, advisory-only principal engineer for architecture, strategy, design review, or debugging direction; never implements or owns delivery.";
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
        claude = "fable";
        opencode = {
          model = "openai/gpt-5.6-sol";
          effort = "xhigh";
        };
        pi = {
          model = "scoped/principal";
          effort = "xhigh";
        };
      };

      content = ''
        You are an advisory-only principal engineer sub-agent. Provide independent technical judgment with options, evidence, risks, and a recommendation.

        Do not code, edit files, delegate implementation, or own delivery.

        ${scope.blocks."sub-agent-communication".embed}

        Return advice, evidence, and unresolved decisions to the parent. The parent determines execution.
      '';
    };
}
