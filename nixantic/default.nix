{
  flake-parts-lib,
  lib,
  ...
}:

{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, pkgs, ... }:
    let
      cfg = config.nixantic;
      instructions = import ./instructions {
        inherit lib pkgs;
        inherit (cfg) postProcess sourceRoots sources;
      };
    in
    {
      options.nixantic = {
        enable = lib.mkEnableOption "nixantic flake package and check integration";

        sourceRoots = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          description = "Source-tree roots to discover nixantic source fragments from before rendering through the flake integration.";
        };

        sources = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.raw;
          default = { };
          description = "Low-level source declarations to render through the nixantic flake integration.";
        };

        postProcess = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Apply markdown post-processing to generated instruction files.";
        };

        packageName = lib.mkOption {
          type = lib.types.str;
          default = "nixantic-instructions";
          description = "Name of the package output containing rendered instructions.";
        };

        checkName = lib.mkOption {
          type = lib.types.str;
          default = "nixantic-instructions";
          description = "Name of the check output validating generic renderer behavior for the configured sources.";
        };

        rendered = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          description = "Rendered nixantic package, checks, harness outputs, and block scopes for this system.";
        };
      };

      config = lib.mkIf cfg.enable {
        nixantic.rendered = instructions;
        packages.${cfg.packageName} = instructions.package;
        checks.${cfg.checkName} = instructions.check;
      };
    }
  );

  config.flake = {
    homeManagerModules = {
      default = ./home-manager.nix;
      nixantic = ./home-manager.nix;
    };
    nixantic = {
      lib = {
        mkInstructions = args: import ./instructions args;
        sourceDiscovery = import ./source-sets.nix;
      };
    };
  };
}
