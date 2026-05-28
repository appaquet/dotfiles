let
  main =
    { scope }:
    {
      description = "Skill loaded from an auto-discovered owner.";
      content = "Beta skill sees ${scope.blocks.alpha-block.reference}.";
    };
in
{
  nixantic.sources.beta-owner.skills."beta-skill" = {
    kind = "directory";
    inherit main;
    files = {
      "reference.md" = {
        kind = "md";
        content = builtins.readFile ./reference.md;
      };
    };
  };
}
