{ scope }:
let
  outputPath = scope.forHarness {
    claude = "CLAUDE.md";
    opencode = "AGENTS.md";
  };
in
{
  heading = "Instructions";
  content = ''
    * Name: AP
    * Environment:
      * OS: NixOS + MacOS (home manager, nix darwin)
      * Shell: fish

    ${scope.blocks."top-level-instructions".embed}

    ${scope.blocks."sub-agents-workflows".embed}

    ${scope.blocks."task-management".embed}

    ${scope.blocks."pre-flight".embed}

    ${scope.blocks."context-understanding".embed}

    ${scope.blocks."problem-solving".embed}

    ${scope.blocks."deep-thinking".embed}
  '';
  inherit outputPath;
}
