{
  # renderFrontmatter :: [ { label :: string, value :: any } ] -> string
  #   Renders a YAML frontmatter block from a list of label/value pairs.
  #
  #   Value rendering rules:
  #     null / []    → omitted from output
  #     bool         → YAML boolean
  #     string/path  → JSON-quoted YAML scalar
  #     list         → YAML flow sequence of quoted scalars
  #     attrset      → YAML mapping, recursively rendered
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

      renderKey = key: if builtins.match "[A-Za-z0-9_-]+" key != null then key else builtins.toJSON key;

      renderScalar =
        value:
        if builtins.isBool value then
          if value then "true" else "false"
        else if builtins.isString value || builtins.isPath value then
          builtins.toJSON (toString value)
        else if builtins.isInt value then
          toString value
        else
          throw "Nixantic frontmatter scalar value must be a string, path, bool, int, or null";

      renderList = values: "[${builtins.concatStringsSep ", " (map renderScalar values)}]";

      indentLines =
        text:
        builtins.concatStringsSep "\n" (
          map (line: if line == "" then "" else "  ${line}") (
            builtins.filter builtins.isString (builtins.split "\n" text)
          )
        );

      renderValue =
        value:
        if value == null || value == [ ] then
          null
        else if builtins.isList value then
          renderList value
        else if builtins.isAttrs value then
          let
            rendered = builtins.filter (entry: entry != null) (
              map (
                key:
                let
                  child = renderValue value.${key};
                in
                if child == null then
                  null
                else if builtins.isAttrs value.${key} then
                  "${renderKey key}:\n${indentLines child}"
                else
                  "${renderKey key}: ${child}"
              ) (builtins.attrNames value)
            );
          in
          if rendered == [ ] then null else builtins.concatStringsSep "\n" rendered
        else
          renderScalar value;

      renderField =
        { label, value }:
        let
          safeLabel = validateLabel label;
          rendered = renderValue value;
        in
        if rendered == null then
          null
        else if builtins.isAttrs value then
          "${safeLabel}:\n${indentLines rendered}"
        else
          "${safeLabel}: ${rendered}";

      nonNull = builtins.filter (f: f != null) (map renderField fields);
    in
    if nonNull == [ ] then "" else "---\n${builtins.concatStringsSep "\n" nonNull}\n---\n";
}
