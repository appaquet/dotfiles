{ inputs, withSystem, ... }:
let
  commonHomeModules = [ inputs.humanfirst-dots.homeManagerModule ];

  mkHomeConfig =
    system: modules: extraArgs:
    withSystem system (
      { pkgs, inputs', ... }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = modules ++ commonHomeModules;

        extraSpecialArgs = {
          inherit inputs inputs';
        }
        // extraArgs;
      }
    );
in
{
  flake.homeConfigurations = {
    "appaquet@deskapp" =
      mkHomeConfig "x86_64-linux"
        [
          ./deskapp.nix
          inputs.secrets.homeManager.common
        ]
        {
          cfg = {
            isNixos = true;
            nvimMinimal = false;
            nvimDevMode = true;
          };
        };

    "appaquet@servapp" =
      mkHomeConfig "x86_64-linux"
        [
          ./servapp.nix
          inputs.secrets.homeManager.common
        ]
        {
          cfg = {
            isNixos = true;
            nvimMinimal = false;
            nvimDevMode = false;
          };
        };

    "appaquet@mbpapp" =
      mkHomeConfig "aarch64-darwin"
        [
          ./mbpapp.nix
          inputs.secrets.homeManager.common
        ]
        {
          cfg = {
            isNixos = false; # macOS, not NixOS
            nvimMinimal = false;
            nvimDevMode = true;
          };
        };

    "appaquet@utm" =
      mkHomeConfig "aarch64-linux"
        [
          ./utm.nix
          inputs.secrets.homeManager.common
        ]
        {
          cfg = {
            isNixos = true;
            nvimMinimal = true;
            nvimDevMode = false;
          };
        };

    "appaquet@piapp" =
      mkHomeConfig "aarch64-linux"
        [
          ./piapp.nix
          inputs.secrets.homeManager.common
        ]
        {
          cfg = {
            isNixos = true;
            nvimMinimal = true;
            nvimDevMode = false;
          };
        };

    "appaquet@piprint" =
      mkHomeConfig "aarch64-linux"
        [
          ./piprint.nix
          inputs.secrets.homeManager.common
        ]
        {
          cfg = {
            isNixos = true;
            nvimMinimal = true;
            nvimDevMode = false;
          };
        };

    "appaquet@piups" =
      mkHomeConfig "aarch64-linux"
        [
          ./piups.nix
          inputs.secrets.homeManager.common
        ]
        {
          cfg = {
            isNixos = true;
            nvimMinimal = true;
            nvimDevMode = false;
          };
        };
  };
}
