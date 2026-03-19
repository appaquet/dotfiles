{ inputs, ... }:
let
  packagesOverlay =
    final: prev:
    let
      system = final.stdenv.hostPlatform.system;
    in
    {
      exo = final.callPackage ./exo { };

      fzf-nix = inputs.fzf-nix.packages.${system}.fzf-nix;

      opencode = inputs.llm-agents.packages.${system}.opencode;
      gemini-cli = inputs.llm-agents.packages.${system}.gemini-cli;
      codex = inputs.llm-agents.packages.${system}.codex;

      # claude-code = final.callPackage ./claude-code/package.nix { };
      claude-code = inputs.llm-agents.packages.${system}.claude-code;
    };

  neovimPluginsOverlay = import ../home-manager/modules/neovim/plugins-overlay.nix;
in
{
  # Export overlays as flake outputs (single source of truth)
  # When adding new overlays, also update nixos/modules/home-manager.nix sharedModules
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
