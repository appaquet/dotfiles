let
  fragment =
    { scope }:
    {
      description = "Command loaded from an auto-discovered owner.";
      content = "Beta command sees ${scope.blocks.alpha-block.reference}.";
      onlyInjectBlockReferences = [ ];
    };
in
{
  nixantic.sources.beta-owner.commands."beta-command" = fragment;
}
