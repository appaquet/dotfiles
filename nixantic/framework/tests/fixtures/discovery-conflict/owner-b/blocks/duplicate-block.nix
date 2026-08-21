let
  fragment = {
    heading = "Duplicate Block B";
    content = "Duplicate content from owner B.";
  };
in
{
  nixantic.sources.owner-b.blocks."duplicate-block" = fragment;
}
