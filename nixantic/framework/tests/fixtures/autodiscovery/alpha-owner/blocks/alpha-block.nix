let
  fragment = {
    heading = "Alpha Block";
    content = "Alpha content from an auto-discovered owner.";
  };
in
{
  nixantic.sources.alpha-owner.blocks."alpha-block" = fragment;
}
