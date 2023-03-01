{ config, pkgs, libs, ... }:

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
      set -g theme_color_scheme base16 # Use `bobthefish_display_colors --all` to list themes

      # Source any local stuff from .profile
      if test -f ~/.profile
        fenv source ~/.profile
      end
    '';

    plugins = [
      {
        name = "bobthefish";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "theme-bobthefish";
          rev = "2dcfcab653ae69ae95ab57217fe64c97ae05d8de";
          sha256 = "118hj100c4bb8hyhr22mrsjhg97pyd24cwb1l39bhryd0k9yc5lc";
        };
      }
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
      k = "kubectl";
      randstr = "randstr 'tr -cd \"[:alnum:]\" < /dev/urandom | fold -w30 | head -n1'";
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
      gts = "git tag --sort version:refname";
    };

    # View more examples here https://github.com/junegunn/fzf-git.sh/blob/main/fzf-git.sh
    functions.gb = ''
      set COMMAND 'git for-each-ref --sort=-committerdate refs/heads/ --format="%(color: red)%(committerdate:short)%(color: 244)|%(color: cyan)%(refname:short)%(color: 244)|%(color: green)%(subject)" --color=always | column -ts"|"'
      FZF_DEFAULT_COMMAND=$COMMAND fzf \
        --ansi \
        --header "enter to checkout, ctrl-d to delete" \
        --bind "ctrl-d:execute(echo {+} | awk '{print \$2}' | xargs git branch -D)+reload:$COMMAND" \
        | awk '{print $2}' | xargs git checkout
    '';

    functions.gcpm = ''
      MSG=(git log --pretty=format:%s | head -n 100 | uniq | head -n 10 | fzf) git commit -m "$MSG"
    '';
  };
}
