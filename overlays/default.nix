{ inputs, ... }:
let
  packagesOverlay =
    final: prev:
    let
      system = final.stdenv.hostPlatform.system;
    in
    {
      macpow = final.callPackage ./macpow { };

      markdown-oxide = final.callPackage ./markdown-oxide { };

      codeburn = final.callPackage ./codeburn { };

      opencode = inputs.llm-agents.packages.${system}.opencode;
      gemini-cli = inputs.llm-agents.packages.${system}.gemini-cli;
      codex = inputs.llm-agents.packages.${system}.codex;

      # claude-code = final.callPackage ./claude-code/package.nix { };
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
