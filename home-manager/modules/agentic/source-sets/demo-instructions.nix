{
  "demo-instructions" = {
    instructions = {
      "rules/source-set-demo" =
        { scope }:
        {
          outputPath = scope.forHarness {
            default = "rules/source-set-demo.md";
          };
          heading = scope.forHarness {
            claude = "Source Set Demo Rules (Claude)";
            opencode = "Source Set Demo Rules (OpenCode)";
          };
          content = ''
            This instruction rule was authored in the `demo-instructions` source set.

            ${scope.forHarness {
              claude = "## Claude section\n\nThis harness-specific content is only rendered for the Claude harness.";
              opencode = "## Opencode section\n\nThis harness-specific content is only rendered for the Opencode harness.";
            }}

            ${scope.blocks."source-set-demo-intro".embed}
          '';
        };
    };
  };
}
