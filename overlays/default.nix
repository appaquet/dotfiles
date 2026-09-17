{ inputs, ... }:
let
  packagesOverlay =
    final: prev:
    let
      system = final.stdenv.hostPlatform.system;
    in
    {
      macpow = final.callPackage ./macpow { };
      jujutsu = final.callPackage ./jj { };
      mboxshell = final.callPackage ./mboxshell { };
    };

  neovimPluginsOverlay = import ../home-manager/modules/neovim/plugins-overlay.nix;
in
{
  flake.overlays = {
    packages = packagesOverlay;
    neovimPlugins = neovimPluginsOverlay;
  };

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          permittedInsecurePackages = [ ];
          allowUnfree = true;
        };
        overlays = [
          packagesOverlay
          neovimPluginsOverlay
        ];
      };
    };
}
