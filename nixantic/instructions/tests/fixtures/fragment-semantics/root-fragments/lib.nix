{
  nixantic.sources.root-fragments.commands."root-lib-command" = {
    description = "Root-level lib fragment command";
    content = "Root-level lib.nix is an ordinary fragment.";
    onlyInjectBlockReferences = [ ];
  };
}
