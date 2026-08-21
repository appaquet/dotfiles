{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  harnesses = import ../harnesses { renderFrontmatter = builders.renderFrontmatter; };
  claude = harnesses.claude;

  command =
    (builders.makeScope {
      harness = claude;
      sources.commands.demo = {
        description = "Demo command";
        content = "Body";
        argumentHint = "[path]";
      };
    }).commands.demo;

  overriddenInstruction =
    (builders.makeScope {
      harness = claude;
      sources.instructions.demo = {
        heading = "Demo";
        content = "Body";
        outputPath = "nested/demo.md";
      };
    }).instructions.demo;
  overriddenArtifacts = builders.makeScope {
    harness = claude;
    sources = {
      agents.demo = {
        description = "Demo agent";
        content = "Body";
        outputPath = "custom/agent.md";
      };
      commands.demo = {
        description = "Demo command";
        content = "Body";
        outputPath = "custom/command.md";
      };
      skills.demo = {
        main = {
          description = "Demo skill";
          content = "Body";
          outputPath = "custom/skill.md";
        };
        files."refs/example.md" = {
          kind = "md";
          content = "Support";
        };
      };
    };
  };

  mkInvalidResult =
    renderer:
    builtins.tryEval (
      (builders.makeScope {
        harness = claude // {
          renderArtifact = renderer;
        };
        sources.instructions.demo = {
          heading = "Demo";
          content = "Body";
        };
      }).instructions.demo.outputPath
    );

  missingRendererField = mkInvalidResult (_: {
    outputPath = "demo.md";
    frontmatter = { };
  });
  duplicateFrontmatterOrder = mkInvalidResult (_: {
    outputPath = "demo.md";
    frontmatter = {
      description = "Demo";
    };
    frontmatterOrder = [
      "description"
      "description"
    ];
  });
  unsafeRendererPath = mkInvalidResult (_: {
    outputPath = "../demo.md";
    frontmatter = { };
    frontmatterOrder = [ ];
  });
  unsafeAuthoredPath = builtins.tryEval (
    (builders.makeScope {
      harness = claude;
      sources.instructions.demo = {
        heading = "Demo";
        content = "Body";
        outputPath = "/demo.md";
      };
    }).instructions.demo.outputPath
  );

  cases = [
    {
      name = "adapter frontmatter follows its explicit order and omits null values";
      pass =
        command.embed
        == "---\nname: \"demo\"\ndescription: \"Demo command\"\nargument-hint: \"[path]\"\n---\n\nBody";
      detail = "expected Claude command frontmatter in adapter-declared order without null fields";
    }
    {
      name = "authored output path overrides renderer default";
      pass = overriddenInstruction.outputPath == "nested/demo.md";
      detail = "expected authored path to win over the renderer default";
    }
    {
      name = "authored overrides apply to entries but not bundled skill support files";
      pass =
        overriddenArtifacts.agents.demo.outputPath == "custom/agent.md"
        && overriddenArtifacts.commands.demo.outputPath == "custom/command.md"
        && overriddenArtifacts.skills.demo.outputPath == "custom/skill.md"
        &&
          overriddenArtifacts.skillFiles."skills/demo/refs/example.md".outputPath
          == "skills/demo/refs/example.md";
      detail = "expected entry overrides and the authored-relative support-file path";
    }
    {
      name = "renderer requires exactly the normalized result fields";
      pass = !missingRendererField.success;
      detail = "expected a renderer result missing frontmatterOrder to fail";
    }
    {
      name = "renderer frontmatter order contains every key once";
      pass = !duplicateFrontmatterOrder.success;
      detail = "expected duplicate frontmatter order keys to fail";
    }
    {
      name = "renderer and authored paths must be safe relative paths";
      pass = !unsafeRendererPath.success && !unsafeAuthoredPath.success;
      detail = "expected absolute and parent-relative paths to fail";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
