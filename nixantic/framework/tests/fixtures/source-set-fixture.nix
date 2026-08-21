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
          role = "main";
          heading = scope.forHarness {
            claude = "Claude";
            opencode = "OpenCode";
            pi = "Pi";
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
