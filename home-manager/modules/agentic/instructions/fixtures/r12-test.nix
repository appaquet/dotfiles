let
  badBlock = (import ./bad-block-reference.nix {
    scope = {
      blocks = { };
      api = { };
      harness = { };
    };
  }).content;
in
badBlock
