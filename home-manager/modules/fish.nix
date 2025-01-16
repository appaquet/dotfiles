{ pkgs, ... }:

{
  home.packages = with pkgs; [
    any-nix-shell # allows using fish for `nix shell`
  ];

  programs.fish = {
    enable = true;
    package = pkgs.fish;

    interactiveShellInit = ''
      # Disable greeting
      set fish_greeting

      # vi mode
      fish_vi_key_bindings

      # Add support for nix run and nix-shell in fish
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source

      # Force term color support
      # Some TUI may not appear correctly otherwise
      set -x TERM xterm-256color
      set -x COLORTERM truecolor

      # Source any local stuff from .profile
      if test -f ~/.profile
        fenv source ~/.profile
      end

      # Enable direnv
      if command -v direnv &>/dev/null
          eval (direnv hook fish)
      end

      # Apparently the plugin doesn't do this for us on MacOS for some reason
      fzf_configure_bindings

      # Some shortcuts (ctrl-alt-c, in iTerm2, need to rebind alt to Esc+)
      bind \cn 'fzf-nix'
      bind \cg 'fzf-ripgrep'
    '';

    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env.src;
      }
    ];

    shellAliases = {
      l = "ls";
      ll = "ls -lash";
      b = "bat";
      randstr = "tr -cd \"[:alnum:]\" < /dev/urandom | fold -w30 | head -n1";
      x = "~/dotfiles/x";
    };

    shellAbbrs = {
      k = "kubectl";

      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      llt = "ll -t"; # sort by time
      lls = "ll -S"; # sort by size

      nr = {
        expansion = "nix run nixpkgs#%";
        setCursor = true;
      };
      ns = {
        expansion = "nix shell nixpkgs#%";
        setCursor = true;
      };
      nrf = "nix run nixpkgs#(fzf-nix)";
      nsf = "nix shell nixpkgs#(fzf-nix)";
      fn = "fzf-nix";

      ai = {
        expansion = "aichat \"%\"";
        setCursor = true;
      };
      aie = {
        expansion = "aichat -e \"%\"";
        setCursor = true;
      };
      aif = "aichat -f";
    };

    functions = {
      # ripgrep & open files in vim
      vimrg = ''
        vim -c "Rg $argv"
      '';
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      command_timeout = 2000;

      username = {
        disabled = false;
        show_always = true;
        style_user = "white";
        style_root = "red";
        format = "[$user]($styte)[@](fg:#808080)";
      };

      hostname = {
        ssh_only = false;
        style = "white";
        format = "[$hostname ]($style)";
      };

      gcloud = {
        disabled = true;
      };
      nix_shell = {
        format = "via [$symbol\($name\)]($style) ";
      };
      package = {
        disabled = true;
      };
      golang = {
        disabled = true;
      };
      nodejs = {
        disabled = true;
      };
      rust = {
        disabled = true;
      };
      buf = {
        disabled = true;
      };
      vagrant = {
        disabled = true;
      };
    };
  };
}
