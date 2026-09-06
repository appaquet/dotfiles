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

      nono = inputs.llm-agents.packages.${system}.nono;

      opencode = inputs.llm-agents.packages.${system}.opencode;
      herdr = inputs.llm-agents.packages.${system}.herdr;
      antigravity-cli = inputs.llm-agents.packages.${system}.antigravity-cli;
      codex = inputs.llm-agents.packages.${system}.codex;
      ccusage = inputs.llm-agents.packages.${system}.ccusage;

      claude-code = inputs.llm-agents.packages.${system}.claude-code;
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
