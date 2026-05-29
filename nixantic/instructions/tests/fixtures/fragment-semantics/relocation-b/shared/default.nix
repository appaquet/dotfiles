{
  nixantic.sources.relocated-owner.commands."relocated-command" = {
    description = "Relocation-invariant command";
    content = "Same exported source-set data.";
    onlyInjectBlockReferences = [ ];
  };
}
