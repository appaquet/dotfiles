{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  output = import ../output.nix { inherit pkgs lib; };
  pi = import ../harnesses/pi.nix { inherit lib; };
  scope = builders.makeScope {
    harness = pi;
    settings.harnesses.pi.rules.output = "merge-main";
    sources = {
      instructions.main = {
        role = "main";
        heading = "Main";
        content = "Main body";
      };
      instructions.rule = {
        role = "rule";
        heading = "Rule";
        content = "Rule body";
      };
      agents.reviewer = {
        description = "Review code";
        content = "Agent body";
        model.pi = {
          model = "provider/model";
          effort = "high";
        };
        permission.pi = {
          tools = [
            "read"
            "bash"
          ];
          disallowedTools = [ "write" ];
          extensions = [ "ext:tasks" ];
          excludeExtensions = [ "ext:unsafe" ];
          skills = false;
          allowedSubagents = [ "explorer" ];
          persistSession = true;
          isolated = true;
          isolation = "worktree";
        };
      };
      commands.demo = {
        description = "Run demo";
        content = "Use $1 and $ARGUMENTS";
        argumentHint = "<path>";
      };
      skills.demo = {
        main = {
          description = "Demo skill";
          content = "Skill body";
          metadata = {
            ignored = "by-pi";
          };
        };
        files."refs/example.md" = {
          kind = "md";
          content = "Support";
        };
      };
    };
  };
  invalidPolicy = builtins.tryEval (
    (builders.makeScope {
      harness = pi;
      sources.agents.invalid = {
        description = "Invalid";
        content = "Agent body";
        permission.pi.permissionMode = "bypassPermissions";
      };
    }).agents.invalid.embed
  );
  invalidPolicyValue = builtins.tryEval (
    (builders.makeScope {
      harness = pi;
      sources.agents.invalid = {
        description = "Invalid";
        content = "Agent body";
        permission.pi.persistSession = "yes";
      };
    }).agents.invalid.embed
  );
  overriddenScope = builders.makeScope {
    harness = pi;
    sources.commands.demo = {
      description = "Run demo";
      content = "Body";
      outputPath = "custom/prompt.md";
    };
  };
  package = output.mkPackage { scopes.pi = scope; };
  bomEntries = package.passthru.bom.entries.pi;

  cases = [
    {
      name = "Pi renders native context, prompt, skill, and support-file paths";
      pass =
        scope.instructions.main.outputPath == "AGENTS.md"
        && scope.commands.demo.outputPath == "prompts/demo.md"
        && scope.skills.demo.outputPath == "skills/demo/SKILL.md"
        && scope.skillFiles."skills/demo/refs/example.md".outputPath == "skills/demo/refs/example.md";
      detail = "expected Pi-native destinations and merged rules in AGENTS.md";
    }
    {
      name = "Pi prompt frontmatter preserves argument hints and Pi argument variables";
      pass =
        scope.commands.demo.embed
        == "---\ndescription: \"Run demo\"\nargument-hint: \"<path>\"\n---\n\nUse $1 and $ARGUMENTS";
      detail = "expected Pi prompt-template frontmatter and unchanged supported argument variables";
    }
    {
      name = "Pi skills render the Agent Skills metadata subset";
      pass =
        scope.skills.demo.embed == "---\nname: \"demo\"\ndescription: \"Demo skill\"\n---\n\nSkill body";
      detail = "expected name and description only, without Claude/OpenCode metadata";
    }
    {
      name = "Pi keeps authored entry paths and logical BOM kinds";
      pass =
        overriddenScope.commands.demo.outputPath == "custom/prompt.md"
        && builtins.any (
          entry: entry.relativePath == "prompts/demo.md" && entry.category == "commands"
        ) bomEntries
        && builtins.any (
          entry: entry.relativePath == "skills/demo/SKILL.md" && entry.category == "skills"
        ) bomEntries
        && builtins.any (
          entry: entry.relativePath == "skills/demo/refs/example.md" && entry.category == "skillSubfiles"
        ) bomEntries;
      detail = "expected common authored-path precedence and logical kinds to survive Pi-native paths";
    }
    {
      name = "tintinweb agents render plugin path and ordered snake_case policy fields";
      pass =
        scope.agents.reviewer.outputPath == "agents/reviewer.md"
        &&
          scope.agents.reviewer.embed
          == "---\nname: \"reviewer\"\ndescription: \"Review code\"\ntools: [\"read\", \"bash\"]\ndisallowed_tools: [\"write\"]\nextensions: [\"ext:tasks\"]\nexclude_extensions: [\"ext:unsafe\"]\nskills: false\nallowed_subagents: [\"explorer\"]\nmodel: \"provider/model\"\nthinking: \"high\"\npersist_session: true\nisolated: true\nisolation: \"worktree\"\n---\n\nAgent body";
      detail = "expected the tintinweb agent schema in its declared field order";
    }
    {
      name = "tintinweb rejects unsupported policy fields";
      pass = !invalidPolicy.success && !invalidPolicyValue.success;
      detail = "expected unsupported fields and invalid values to fail instead of being silently ignored";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
