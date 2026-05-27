/*
  Shared YAML frontmatter renderer — used by all harnesses (Claude, Opencode)
  to emit frontmatter blocks. Each harness calls renderFrontmatter with its
  selected field set; null fields are automatically omitted.

  Constructors in builders.nix pass all authored fields to the harness; the
  harness selects which to include. This renderer handles formatting and null
  suppression.
*/
{
  # renderFrontmatter :: [ { label :: string, value :: any } ] -> string
  #   Renders a YAML frontmatter block from a list of label/value pairs.
  #
  #   Value rendering rules:
  #     null / []   → omitted from output
  #     bool        → "true" or "false"
  #     list        → comma-separated values
  #     other       → toString
  #
  #   Output: "---\n<lines>\n---\n" or "" if all values are null/empty.
  #
  #   Called by harness render functions (renderAgentFrontmatter,
  #   renderCommandFrontmatter, renderSkillFrontmatter) to produce the final
  #   frontmatter string prepended to instruction content.
  renderFrontmatter =
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
}
