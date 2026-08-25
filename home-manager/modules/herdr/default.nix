{ lib, pkgs, ... }:
let
  worktreeHooks = {
    path = pkgs.stdenvNoCC.mkDerivation {
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

    config = (pkgs.formats.toml { }).generate "herdr-worktree-hooks.toml" {
      default = {
        # TODO: Replace by jj workspace sync once stable https://github.com/jj-vcs/jj/pull/9943
        created = [ ''echo "herdr worktree created: $WT_WORKTREE_PATH" >> /tmp/herdr-worktree-hooks.log'' ];
        opened = [ ];
        removed = [ ];
      };
    };
  };

  managedPlugins = {
    worktree-hooks = worktreeHooks;
  };
in
{
  imports = [ ./hm.nix ];

  programs.herdr = {
    enable = true;

    settings = {
      onboarding = false;

      terminal = {
        default_shell = "fish";
      };

      session = {
        resume_agents_on_restore = false; # doesn't restore via nono correctly
      };

      keys = {
        prefix = "ctrl+a";

        next_agent = "ctrl+'";
        previous_agent = "ctrl+;";

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

      ui = {
        window_title = "{hostname}: {workspace}";
        mobile_width_threshold = 100;
        toast = {
          delivery = "terminal"; # OSC 9/777 via attached terminal; works local + herdr --remote
        };
      };
    };

    managedPlugins = managedPlugins;
  };
}
