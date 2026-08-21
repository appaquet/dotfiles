{ pkgs, lib }:

/*
  Home Manager install.files guard tests — exercise the duplicate-target
  detection in nixantic/home-manager.nix without a full Home Manager
  evaluation. The module is evaluated with lib.evalModules and a minimal stub
  for the home.file option it writes into.
*/

let
  homeFileStub =
    { lib, ... }:
    {
      options.home.file = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        default = { };
      };
      options.home.packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
    };

  evalWith =
    installFiles:
    let
      evaluation = lib.evalModules {
        modules = [
          homeFileStub
          ../../modules/home-manager.nix
          {
            _module.args = { inherit pkgs; };
            nixantic.instructions.install.files = installFiles;
          }
        ];
      };
    in
    builtins.deepSeq evaluation.config.home.file evaluation.config;

  uniqueInstallFiles = [
    {
      harness = "claude";
      source = "CLAUDE.md";
      target = ".claude/CLAUDE.md";
    }
    {
      harness = "claude";
      source = "commands/foo.md";
      target = ".claude/commands/foo.md";
    }
    {
      harness = "pi";
      source = "AGENTS.md";
      target = ".pi/agent/AGENTS.md";
    }
    {
      harness = "pi";
      source = "prompts/foo.md";
      target = ".pi/agent/prompts/foo.md";
    }
    {
      harness = "pi";
      source = "skills/foo/SKILL.md";
      target = ".pi/agent/skills/foo/SKILL.md";
    }
    {
      harness = "pi";
      source = "agents/foo.md";
      target = ".pi/agent/agents/foo.md";
    }
  ];
  uniqueTargetsResult = builtins.tryEval (evalWith uniqueInstallFiles);
  uniqueInstallSources = if uniqueTargetsResult.success then evalWith uniqueInstallFiles else { };

  duplicateTargetResult = builtins.tryEval (evalWith [
    {
      harness = "claude";
      source = "CLAUDE.md";
      target = ".claude/shared.md";
    }
    {
      harness = "opencode";
      source = "AGENTS.md";
      target = ".claude/shared.md";
    }
  ]);

  invalidHarnessResult = builtins.tryEval (evalWith [
    {
      harness = "not-a-built-in-harness";
      source = "README.md";
      target = ".agent/README.md";
    }
  ]);

  cases = [
    {
      name = "distinct install.files targets evaluate";
      pass = uniqueTargetsResult.success;
      detail = "expected install.files with distinct targets to evaluate without error";
    }
    {
      name = "Pi install.files sources resolve under the Pi package tree";
      pass =
        uniqueTargetsResult.success
        &&
          uniqueInstallSources.home.file.".pi/agent/AGENTS.md".source
          == "${uniqueInstallSources.nixantic.instructions.package}/pi/AGENTS.md"
        &&
          uniqueInstallSources.home.file.".pi/agent/prompts/foo.md".source
          == "${uniqueInstallSources.nixantic.instructions.package}/pi/prompts/foo.md"
        &&
          uniqueInstallSources.home.file.".pi/agent/skills/foo/SKILL.md".source
          == "${uniqueInstallSources.nixantic.instructions.package}/pi/skills/foo/SKILL.md"
        &&
          uniqueInstallSources.home.file.".pi/agent/agents/foo.md".source
          == "${uniqueInstallSources.nixantic.instructions.package}/pi/agents/foo.md";
      detail = "expected generic Home Manager mappings to resolve representative Pi context, prompt, skill, and agent files";
    }
    {
      name = "duplicate install.files target fails";
      pass = !duplicateTargetResult.success;
      detail = "expected two install.files mapping to the same target to fail evaluation";
    }
    {
      name = "install.files rejects harnesses outside built-in registry";
      pass = !invalidHarnessResult.success;
      detail = "expected install.files harness to be validated against the shared built-in registry";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
