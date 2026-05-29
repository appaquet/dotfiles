{
  "source-set-fixture" = {
    blocks = {
      "test-block" = {
        heading = "Test Block from Fixture";
        content = "This block was authored through the source-set fixture and proves the dendritic pipeline works.";
      };
    };

    instructions = {
      main =
        { scope }:
        {
          outputPath = scope.forHarness {
            claude = "CLAUDE.md";
            opencode = "AGENTS.md";
          };
          heading = scope.forHarness {
            claude = "Claude";
            opencode = "OpenCode";
          };
          content = ''
            # Fixture-Generated Instructions

            This file was generated entirely from a source-set fixture.

            ${scope.blocks."test-block".embed}
          '';
        };
    };
  };
}
