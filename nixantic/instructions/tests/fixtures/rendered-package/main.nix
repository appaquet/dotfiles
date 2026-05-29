{
  nixantic.sources.rendered-package = {
    commands."safe-command" = {
      description = "Run: safely # not a YAML comment";
      argumentHint = "[path:with:colon]";
      allowedTools = [
        "Bash(command: test)"
        "Read # docs"
      ];
      content = ''
        Command body.
      '';
    };

    skills."safe-skill" = {
      main = {
        description = "Skill: safe # quoted";
        content = ''
          Skill body.
        '';
      };
      files."refs/example.md" = {
        kind = "md";
        content = "Bundled reference body.";
      };
    };

    instructions.main =
      { scope }:
      {
        heading = scope.forHarness {
          claude = "Rendered Package Claude";
          opencode = "Rendered Package OpenCode";
        };
        content = "Main body.";
        outputPath = scope.forHarness {
          claude = "CLAUDE.md";
          opencode = "AGENTS.md";
        };
      };
  };
}
