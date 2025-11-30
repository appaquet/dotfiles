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
          (inputs.secrets.init "linux").commonHome
        ]
        {
          secrets = inputs.secrets.init "linux";

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
          (inputs.secrets.init "linux").commonHome
        ]
        {
          secrets = inputs.secrets.init "linux";
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
          (inputs.secrets.init "darwin").commonHome
        ]
        {
          secrets = inputs.secrets.init "darwin";
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
          (inputs.secrets.init "linux").commonHome
        ]
        {
          secrets = inputs.secrets.init "linux";
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
          (inputs.secrets.init "linux").commonHome
        ]
        {
          secrets = inputs.secrets.init "linux";
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
          (inputs.secrets.init "linux").commonHome
        ]
        {
          secrets = inputs.secrets.init "linux";
          cfg = {
            isNixos = true;
            nvimMinimal = true;
            nvimDevMode = false;
          };
        };
  };
}
