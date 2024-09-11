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

      # Term color support + theme
      set -x TERM xterm-256color
      set -g theme_display_cmd_duration no
      set -g theme_display_date no
      set -g theme_newline_cursor yes # have prompt start on sep line
      set -g theme_color_scheme base16 # Use `bobthefish_display_colors --all` to list themes

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

      # Some shortcuts (ctrl-alt-c, in iTerm2, rebind alt to Esc+)
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
      randstr = "randstr 'tr -cd \"[:alnum:]\" < /dev/urandom | fold -w30 | head -n1'";
      x = "~/dotfiles/x";
    };

    shellAbbrs = {
      gs = "git status";
      gl = "git log";
      gls = "git log --stat";
      glm = "git log --merges --first-parent";
      gd = "git diff";
      gds = "git diff --staged";
      gp = "git pull";
      gck = "git checkout";
      gcm = "git commit -m";
      gchm = "git commit -m (git log -1 --pretty=format:%s)";
      gpom = "git pull origin master";
      gpr = "git pull --rebase --autostash";
      gca = "git commit --amend";
      gr = "git rev-parse --short=7 @";
      grsw = "git restore --staged --worktree";
      grws = "git restore --staged --worktree";
      grs = "git restore --staged";
      ghpr = "gh pr create --draft --body \"\" --title";
      ghck = "git checkout (gh-pr-select)";
      gts = "git tag -l --sort=-version:refname --format='%(refname:short) (%(creatordate:short))'";
      gau = "git add -u";
      gmr = "git maintenance run";

      k = "kubectl";
      d = "docker";

      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      llt = "ll -t"; # sort by time
      lls = "ll -S"; # sort by size

      nr = "nix run nixpkgs#(fzf-nix)";
      ns = "nix shell nixpkgs#(fzf-nix)";
    };

    functions = {
      # Reload fish with latest paths from nix.
      # If not working, make sure that fish_user_paths are correctly set as explained in the README.
      reload = ''
        set CLEAR (which clear)
        set -e PATH
        set -e __HM_SESS_VARS_SOURCED
        $CLEAR
        ~/.nix-profile/bin/fish
      '';

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

      gcloud = { disabled = true; };
      nix_shell = {
        format = "via [$symbol\($name\)]($style) ";
      };
      package = { disabled = true; };
      golang = { disabled = true; };
      nodejs = { disabled = true; };
      rust = { disabled = true; };
      buf = { disabled = true; };
      vagrant = { disabled = true; };
    };
  };
}
