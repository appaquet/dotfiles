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

      # If colors are messed up, check:
      # https://gist.github.com/andersevenrud/015e61af2fd264371032763d4ed965b6
      # Don't set TERM here, it should be set via tmux (see tmux/default.nix)
      export COLORTERM=truecolor

      # Since it doesn't seem to always work in neovim setup
      export EDITOR="nvim"

      # Add support for nix run and nix-shell in fish
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source

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
      bind -M insert ctrl-alt-n 'fzf-nix'
      bind -M insert ctrl-alt-g 'fzf-ripgrep'
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
      randstr = "tr -cd \"[:alnum:]\" < /dev/urandom | fold -w30 | head -n1";
      x = "~/dotfiles/x";

      b = "bat";
      c = "bat";

      l = "lsd";
      ll = "lsd -l";
    };

    shellAbbrs = {
      k = "kubectl";

      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      lla = "lsd -lA";
      llt = "lsd -lt"; # sort by time
      llth = "lsd -lt --color=always | head -n 20"; # sort by time, top 20
      lls = "lsd -lS"; # sort by size
      llsh = "lsd -lS --color=always | head -n 20"; # sort by size, top 20

      nr = {
        expansion = "nix run nixpkgs#%";
        setCursor = true;
      };
      nru = {
        expansion = "nix run github:NixOS/nixpkgs/nixpkgs-unstable#%";
        setCursor = true;
      };
      ns = {
        expansion = "nix shell nixpkgs#%";
        setCursor = true;
      };
      nsu = {
        expansion = "nix shell github:NixOS/nixpkgs/nixpkgs-unstable#%";
        setCursor = true;
      };
      nrf = "nix run nixpkgs#(fzf-nix)";
      nrfu = "nix run github:NixOS/nixpkgs/nixpkgs-unstable#(fzf-nix)";
      nsf = "nix shell nixpkgs#(fzf-nix)";
      nsfu = "nix shell github:NixOS/nixpkgs/nixpkgs-unstable#(fzf-nix)";
      fn = "fzf-nix";

      nv = "nvim";
    };

    functions = {
      # ripgrep & open files in vim
      vimrg = ''
        vim -c "Rg $argv"
      '';

      # execute a command in a directory
      "in" = ''
        set dir $argv[1]
        set cmd $argv[2..-1]
        pushd $dir
        eval $cmd
        popd
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

      direnv = {
        disabled = false;
        format = "[$symbol$allowed]($style) ";
        symbol = "direnv ";
        allowed_msg = "✓";
        not_allowed_msg = "⚠️";
        denied_msg = "🚫";
        style = "dimmed green";
      };

      gcloud = {
        disabled = true;
      };
      nix_shell = {
        disabled = true;
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
