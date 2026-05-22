let
  renderFrontmatterUnchecked =
    fields:
    let
      renderField =
        { label, value }:
        if value == null then
          null
        else if builtins.isBool value then
          "${label}: ${if value then "true" else "false"}"
        else if builtins.isList value then
          "${label}: ${builtins.concatStringsSep ", " value}"
        else
          "${label}: ${toString value}";

      nonNull = builtins.filter (f: f != null) (map renderField fields);
    in
    if nonNull == [ ] then "" else "---\n${builtins.concatStringsSep "\n" nonNull}\n---\n";

  renderFrontmatter = renderFrontmatterUnchecked;
in
{
  inherit renderFrontmatter renderFrontmatterUnchecked;
}
