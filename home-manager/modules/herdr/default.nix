{ lib, pkgs, ... }:
let
  worktreeHooks = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr-worktree-hooks";
    version = "0.2.0";
    src = pkgs.fetchFromGitHub {
      owner = "timofey-TK";
      repo = "herdr-worktree-hooks";
      rev = "c3cfa359bd472d7ef4c639e65f2fadda10503a74";
      hash = "sha256-fI2YhcP5FKk8PK1mat7Yi6g6yTrXLZqAea2sXsBBf6c=";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out"
      cp -R ./* "$out/"
    '';
  };

  worktreeHooksConfig = (pkgs.formats.toml { }).generate "herdr-worktree-hooks.toml" {
    default = {
      # TODO: Replace by jj workspace sync once stable https://github.com/jj-vcs/jj/pull/9943
      created = [ ''echo "herdr worktree created: $WT_WORKTREE_PATH" >> /tmp/herdr-worktree-hooks.log'' ];
      opened = [ ];
      removed = [ ];
    };
  };

  managedPlugins = {
    worktree-hooks = {
      path = worktreeHooks;
      config = worktreeHooksConfig;
    };
  };
in
{
  imports = [ ./config.nix ];

  programs.herdr = {
    enable = true;

    settings = {
      onboarding = false;

      terminal = {
        default_shell = "fish";
      };

      keys = {
        prefix = "ctrl+a";

        command = [
          {
            key = "prefix+t";
            type = "popup";
            command = lib.getExe pkgs.btop;
            description = "Open btop system monitor";
            width = "90%";
            height = "90%";
          }
        ];
      };

      theme = {
        name = "catppuccin";
        auto_switch = true;
        light_name = "catppuccin-latte";
        dark_name = "catppuccin";
      };
    };

    managedPlugins = managedPlugins;
  };
}
