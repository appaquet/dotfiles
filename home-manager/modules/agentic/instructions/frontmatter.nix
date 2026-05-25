let
  renderFrontmatterUnchecked =
    fields:
    let
      renderField =
        { label, value }:
        if value == null || value == [ ] then
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

  # REVIEW: architecture-reviewer - `renderFrontmatter` and `renderFrontmatterUnchecked` are
  # identical bindings with no distinguishing behavior. The naming implies there should be a
  # "checked" variant with validation (e.g., asserting well-formed labels, no duplicate fields).
  # Either add the validation layer or collapse to a single binding to avoid misleading naming.
  renderFrontmatter = renderFrontmatterUnchecked;
in
{
  inherit renderFrontmatter renderFrontmatterUnchecked;
}
