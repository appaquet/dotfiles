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
    };

  evalWith =
    installFiles:
    (lib.evalModules {
      modules = [
        homeFileStub
        ../../home-manager.nix
        {
          _module.args = { inherit pkgs; };
          nixantic.instructions.install.files = installFiles;
        }
      ];
    }).config.home.file;

  uniqueTargetsResult = builtins.tryEval (evalWith [
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
  ]);

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

  cases = [
    {
      name = "distinct install.files targets evaluate";
      pass = uniqueTargetsResult.success;
      detail = "expected install.files with distinct targets to evaluate without error";
    }
    {
      name = "duplicate install.files target fails";
      pass = !duplicateTargetResult.success;
      detail = "expected two install.files mapping to the same target to fail evaluation";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
