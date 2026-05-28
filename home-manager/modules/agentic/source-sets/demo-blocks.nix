{
  "demo-blocks" = {
    blocks = {
      "source-set-demo-intro" = {
        heading = "Source Set Demo";
        content = ''
          This block was authored in a source set. Source sets group related artifacts
          together under an owner key while the renderer flattens all blocks into a
          single shared namespace after normalization.

          Cross-source-set references need no prefix — all blocks share the flat
          `scope.blocks.*` namespace regardless of which source set they came from.
        '';
      };
    };
  };
}
