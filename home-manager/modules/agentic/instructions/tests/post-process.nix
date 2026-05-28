{ pkgs, lib }:
let
  output = import ../output.nix { inherit pkgs lib; };
  inherit (output) postProcessContent;

  cases = [
    {
      name = "trailing single dot stripped";
      input = "foo.";
      expected = "foo";
    }
    {
      name = "double trailing dot becomes single dot";
      input = "foo..";
      expected = "foo.";
    }
    {
      name = "lone dot line removed";
      input = ".";
      expected = "";
    }
    {
      name = "blank line removed";
      input = "";
      expected = "";
    }
    {
      name = "whitespace-only line removed";
      input = "   ";
      expected = "";
    }
    {
      name = "line without trailing dot preserved";
      input = "hello world";
      expected = "hello world";
    }
    {
      name = "mixed multiline content";
      input = ''
        foo.
        bar..
        baz
        .

        hello world.
      '';
      expected = "foo\nbar.\nbaz\nhello world";
    }
    {
      name = "empty input";
      input = "";
      expected = "";
    }
    {
      name = "only newlines";
      input = "\n\n";
      expected = "";
    }
    {
      name = "dot in middle preserved";
      input = "foo.bar";
      expected = "foo.bar";
    }
  ];

  checkCase =
    case:
    let
      result = postProcessContent case.input;
    in
    if result == case.expected then
      true
    else
      throw "FAIL [${case.name}]: expected '${
        builtins.replaceStrings [ "\n" ] [ "\\n" ] case.expected
      }', got '${builtins.replaceStrings [ "\n" ] [ "\\n" ] result}'";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
