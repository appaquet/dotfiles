{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  harness = import ../harnesses/claude.nix { renderFrontmatter = builders.renderFrontmatter; };

  mkScope =
    mode:
    builders.makeScope {
      inherit harness;
      settings.versionControl.mode = mode;
      sources = {
        blocks = { };
        agents = {
          visible-agent = {
            when = { scope }: scope.settings.versionControl.mode == "git";
            description = "Visible in git mode";
            content = "agent";
          };
        };
        commands = {
          visible-command = {
            when = { scope }: scope.settings.versionControl.mode == "git";
            description = "Visible in git mode";
            content = "command";
          };
        };
        skills = {
          visible-skill = {
            main = {
              when = { scope }: scope.settings.versionControl.mode == "git";
              description = "Visible in git mode";
              content = "skill";
            };
            files = { };
          };
        };
        instructions = {
          selected =
            { scope }:
            {
              when = { scope }: scope.settings.versionControl.mode == "git";
              heading = "Selected";
              content = scope.forSetting "versionControl.mode" {
                jj = "jj content";
                git = "git content";
              };
            };
        };
      };
    };

  gitScope = mkScope "git";
  jjScope = mkScope "jj";
  invalidWhen = builtins.tryEval (
    (builders.makeScope {
      inherit harness;
      settings.versionControl.mode = "git";
      sources.instructions.invalid = {
        when = { scope }: "not a bool";
        heading = "Invalid";
        content = "invalid";
      };
    }).instructions.invalid
  );

  cases = [
    {
      name = "settings are visible to authored source functions";
      pass = lib.hasInfix "git content" gitScope.instructions.selected.embed;
      detail = "expected git-selected content";
    }
    {
      name = "when-gated instructions are omitted";
      pass = !(builtins.hasAttr "selected" jjScope.instructions);
      detail = "expected selected instruction omitted in jj mode";
    }
    {
      name = "when-gated agents commands and skills are omitted";
      pass = jjScope.agents == { } && jjScope.commands == { } && jjScope.skills == { };
      detail = "expected major artifact kinds omitted in jj mode";
    }
    {
      name = "when predicate must return a boolean";
      pass = !invalidWhen.success;
      detail = "expected invalid when predicate result to fail evaluation";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
