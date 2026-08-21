{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  claude = import ../harnesses/claude.nix { renderFrontmatter = builders.renderFrontmatter; };
  opencode = import ../harnesses/opencode.nix { renderFrontmatter = builders.renderFrontmatter; };

  agentSource = {
    description = "Agent with harness-specific model and effort";
    content = "Agent body";
    model = {
      claude = "sonnet";
      opencode = {
        model = "openai/gpt-5.6-luna";
        effort = "xhigh";
      };
    };
    permission = {
      claude = {
        disallowedTools = [ "Agent" ];
      };
      opencode = {
        task = "deny";
      };
    };
  };

  renderAgent =
    harness:
    (builders.makeScope {
      inherit harness;
      sources.agents."tiered-agent" = agentSource;
    }).agents."tiered-agent".embed;

  claudeAgent = renderAgent claude;
  opencodeAgent = renderAgent opencode;

  claudeExpected = builtins.concatStringsSep "\n" [
    "---"
    "name: \"tiered-agent\""
    "description: \"Agent with harness-specific model and effort\""
    "model: \"sonnet\""
    "disallowedTools: [\"Agent\"]"
    "---"
    ""
    "Agent body"
  ];

  opencodeExpected = builtins.concatStringsSep "\n" [
    "---"
    "mode: \"subagent\""
    "description: \"Agent with harness-specific model and effort\""
    "model: \"openai/gpt-5.6-luna\""
    "reasoningEffort: \"xhigh\""
    "permission:"
    "  task: \"deny\""
    "---"
    ""
    "Agent body"
  ];

  cases = [
    {
      name = "Claude agent selects its model from string, omits OpenCode-only effort, and renders disallowedTools permission";
      pass = claudeAgent == claudeExpected;
      detail = "expected Claude sonnet model with no effort field and disallowedTools: [\"Agent\"]";
    }
    {
      name = "OpenCode agent selects its model and effort from nested attrset";
      pass = opencodeAgent == opencodeExpected;
      detail = "expected OpenCode selects its model from nested model attrset, and effort, and subagent mode";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
