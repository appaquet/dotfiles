{ inputs, ... }:
{
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
          (final: prev: {
            exo = final.callPackage ./exo { };
            claude-code = final.callPackage ./claude-code { };
          })

          (import ../home-manager/modules/neovim/plugins-overlay.nix)
        ];
      };
    };
}
