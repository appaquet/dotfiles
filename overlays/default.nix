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
            exo = prev.callPackage ./exo { };
            claude-code = prev.callPackage ./claude-code { };
          })

          (import ../home-manager/modules/neovim/plugins-overlay.nix)
        ];
      };
    };
}
