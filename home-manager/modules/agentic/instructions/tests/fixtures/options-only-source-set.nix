{
  "options-only-fixture" = {
    blocks = {
      "test-block" = {
        heading = "Test Block from Fixture";
        content = "This block was authored through the options-only source-set fixture and proves the dendritic pipeline works without directory sources.";
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

            This file was generated entirely from a source-set fixture in options-only mode.
            No directory sources were used during rendering.

            ${scope.blocks."test-block".embed}
          '';
        };
    };
  };
}
