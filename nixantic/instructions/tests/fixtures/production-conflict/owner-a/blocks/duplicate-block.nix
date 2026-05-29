let
  fragment = {
    heading = "Duplicate Block A";
    content = "Duplicate content from owner A.";
  };
in
{
  nixantic.sources.owner-a.blocks."duplicate-block" = fragment;
}
