{ lib, flake-parts-lib, ... }:

{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, pkgs, ... }: {
      options.nixantic = {
        enable = lib.mkEnableOption "nixantic flake package and check exposure";
        packageName = lib.mkOption {
          type = lib.types.str;
          default = "nixantic-instructions";
        };
        checkName = lib.mkOption {
          type = lib.types.str;
          default = "nixantic-instructions";
        };
        modules = lib.mkOption {
          type = lib.types.listOf lib.types.deferredModule;
          default = [ ];
          description = "Additional core-module fragments used only to evaluate exposed packages and checks.";
        };
      };

      config = lib.mkIf config.nixantic.enable (
        let
          evaluated = lib.evalModules {
            specialArgs = { inherit pkgs; };
            modules = [ ../modules/core.nix ] ++ config.nixantic.modules;
          };
          instructions = evaluated.config.nixantic.instructions;
        in
        {
          packages.${config.nixantic.packageName} = instructions.package;
          checks.${config.nixantic.checkName} = instructions.check;
        }
      );
    }
  );
}
