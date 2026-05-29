{
  # renderFrontmatter :: [ { label :: string, value :: any } ] -> string
  #   Renders a YAML frontmatter block from a list of label/value pairs.
  #
  #   Value rendering rules:
  #     null / []   → omitted from output
  #     bool        → YAML boolean
  #     string/path → JSON-quoted YAML scalar
  #     list        → YAML flow sequence of quoted scalars
  #
  #   Output: "---\n<lines>\n---\n" or "" if all values are null/empty.
  renderFrontmatter =
    fields:
    let
      validateLabel =
        label:
        if builtins.match "[A-Za-z0-9_-]+" label != null then
          label
        else
          throw "Nixantic frontmatter label '${label}' is not YAML-safe; use letters, numbers, '_' or '-'";

      renderScalar =
        value:
        if builtins.isBool value then
          if value then "true" else "false"
        else if builtins.isString value || builtins.isPath value then
          builtins.toJSON (toString value)
        else if builtins.isInt value then
          toString value
        else
          throw "Nixantic frontmatter value must be a string, path, bool, int, null, or list of those values";

      renderList = values: "[${builtins.concatStringsSep ", " (map renderScalar values)}]";

      renderField =
        { label, value }:
        let
          safeLabel = validateLabel label;
        in
        if value == null || value == [ ] then
          null
        else if builtins.isList value then
          "${safeLabel}: ${renderList value}"
        else
          "${safeLabel}: ${renderScalar value}";

      nonNull = builtins.filter (f: f != null) (map renderField fields);
    in
    if nonNull == [ ] then "" else "---\n${builtins.concatStringsSep "\n" nonNull}\n---\n";
}
