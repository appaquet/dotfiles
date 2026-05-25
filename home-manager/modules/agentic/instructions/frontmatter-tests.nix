let
  frontmatter = import ./frontmatter.nix;

  cases = [
    {
      name = "required only fields";
      fields = [
        {
          label = "name";
          value = "test";
        }
        {
          label = "model";
          value = "haiku";
        }
      ];
      expected = "---\nname: test\nmodel: haiku\n---\n";
    }
    {
      name = "null omitted";
      fields = [
        {
          label = "name";
          value = "test";
        }
        {
          label = "optional";
          value = null;
        }
        {
          label = "model";
          value = "haiku";
        }
      ];
      expected = "---\nname: test\nmodel: haiku\n---\n";
    }
    {
      name = "boolean true";
      fields = [
        {
          label = "subtask";
          value = true;
        }
      ];
      expected = "---\nsubtask: true\n---\n";
    }
    {
      name = "boolean false";
      fields = [
        {
          label = "subtask";
          value = false;
        }
      ];
      expected = "---\nsubtask: false\n---\n";
    }
    {
      name = "stable caller order";
      fields = [
        {
          label = "z";
          value = "last";
        }
        {
          label = "a";
          value = "first";
        }
      ];
      expected = "---\nz: last\na: first\n---\n";
    }
    {
      name = "all-null / empty output";
      fields = [
        {
          label = "a";
          value = null;
        }
        {
          label = "b";
          value = null;
        }
      ];
      expected = "";
    }
    {
      name = "empty fields";
      fields = [ ];
      expected = "";
    }
    {
      name = "list with multiple entries";
      fields = [
        {
          label = "allowed-tools";
          value = [
            "Bash"
            "Read"
          ];
        }
      ];
      expected = "---\nallowed-tools: Bash, Read\n---\n";
    }
    {
      name = "list single entry";
      fields = [
        {
          label = "allowed-tools";
          value = [ "Bash" ];
        }
      ];
      expected = "---\nallowed-tools: Bash\n---\n";
    }
    {
      name = "list empty";
      fields = [
        {
          label = "allowed-tools";
          value = [ ];
        }
      ];
      expected = "";
    }
  ];

  checkCase =
    case:
    let
      result = frontmatter.renderFrontmatterUnchecked case.fields;
    in
    if result == case.expected then
      true
    else
      throw "FAIL [${case.name}]: expected '${case.expected}', got '${result}'";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
