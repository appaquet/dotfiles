let
  frontmatter = import ../frontmatter.nix;

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
      expected = "---\nname: \"test\"\nmodel: \"haiku\"\n---\n";
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
      expected = "---\nname: \"test\"\nmodel: \"haiku\"\n---\n";
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
      expected = "---\nz: \"last\"\na: \"first\"\n---\n";
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
      expected = "---\nallowed-tools: [\"Bash\", \"Read\"]\n---\n";
    }
    {
      name = "list single entry";
      fields = [
        {
          label = "allowed-tools";
          value = [ "Bash" ];
        }
      ];
      expected = "---\nallowed-tools: [\"Bash\"]\n---\n";
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
    {
      name = "yaml-sensitive scalar characters are quoted";
      fields = [
        {
          label = "description";
          value = "Use foo: bar # not a comment\nnext line";
        }
      ];
      expected = "---\ndescription: \"Use foo: bar # not a comment\\nnext line\"\n---\n";
    }
    {
      name = "yaml-sensitive list entries are quoted";
      fields = [
        {
          label = "allowed-tools";
          value = [
            "Bash(command: test)"
            "Read # docs"
          ];
        }
      ];
      expected = "---\nallowed-tools: [\"Bash(command: test)\", \"Read # docs\"]\n---\n";
    }
    {
      name = "nested attrsets render as yaml mappings";
      fields = [
        {
          label = "permission";
          value = {
            task = "deny";
            bash = {
              "*" = "ask";
              "git *" = "allow";
            };
          };
        }
      ];
      expected = ''
        ---
        permission:
          bash:
            "*": "ask"
            "git *": "allow"
          task: "deny"
        ---
      '';
    }
  ];

  invalidLabelResult = builtins.tryEval (
    frontmatter.renderFrontmatter [
      {
        label = "bad:label";
        value = "x";
      }
    ]
  );

  invalidValueResult = builtins.tryEval (
    frontmatter.renderFrontmatter [
      {
        label = "pi";
        value = 3.14;
      }
    ]
  );

  checkCase =
    case:
    let
      result = frontmatter.renderFrontmatter case.fields;
    in
    if result == case.expected then
      true
    else
      throw "FAIL [${case.name}]: expected '${case.expected}', got '${result}'";

  allPass =
    builtins.foldl' (acc: case: acc && checkCase case) true cases
    && !invalidLabelResult.success
    && !invalidValueResult.success;
in
{
  inherit allPass;
}
