{ pkgs, config, ... }:

let
  # See https://stackoverflow.com/questions/53658303/fetchfromgithub-filter-down-and-use-as-environment-etc-file-source
  dotTmuxRepo = pkgs.fetchFromGitHub {
    owner = "gpakosz"; # https://github.com/gpakosz/.tmux
    repo = ".tmux";
    rev = "129d6e7ff3ae6add17f88d6737810bbdaa3a25cf";
    sha256 = "sha256-i+5ZI2msYk0Ta5Lytb/qpEixp9uhiAqTGO5VHbNRiwg=";
    stripRoot = false;
  };

  dotTmuxConfFile = "${dotTmuxRepo}/.tmux-129d6e7ff3ae6add17f88d6737810bbdaa3a25cf/.tmux.conf";
in
{
  # gpakosz/.tmux expect its files to be at specific locations
  home.file.".tmux.conf".source = dotTmuxConfFile;
  home.file.".tmux.conf.local".source = ./tmux.conf.local;

  home.packages = with pkgs; [
    tmux
  ];

  programs.tmux = {
    enable = true;
    package = pkgs.tmux;

    extraConfig = ''
      # Specify plugins here since tpm looks for plugins in xdg config
      set -g @plugin 'tmux-plugins/tmux-resurrect'

      # Loads gpakosz/.tmux configuration & .tmux.conf.local
      source-file ~/.tmux.conf

      # Synchronized panes
      bind S setw synchronize-panes\; display-message "Synchronized pane is now #{?synchronize-panes,on,off}"

      # Clear the screen
      bind C-k setw synchronize-panes\; send-keys C-l \; setw synchronize-panes

      # Move windows right/left
      bind -r C-y swap-window -t -1 \; select-window -t -1  # swap current window with the previous one
      bind -r C-u swap-window -t +1 \; select-window -t +1  # swap current window with the next one

      # Space to toggle terminal in 2 split panes with editor on top
      unbind Space
      bind-key Space run-shell ' \
        pane_title=$(tmux display-message -p "#{pane_title}"); \
        in_vim=$(echo $pane_title | grep -c "vim"); \
        is_zoomed=$(tmux display-message -p "#{window_zoomed_flag}"); \
        if [ "$in_vim" == "1" ]; then \
          if [ "$is_zoomed" == "1" ]; then \
            tmux resize-pane -Z; \
            tmux select-pane -D; \
          else \
            tmux select-pane -D; \
          fi; \
        else \
          if [ "$is_zoomed" == "1" ]; then \
            tmux select-pane -U; \
          else \
            tmux select-pane -U; \
            tmux resize-pane -Z; \
          fi; \
        fi
      '

      # Fixes issue on macOS where shell in tmux is not right
      # See https://github.com/tmux/tmux/issues/4162
      set -gu default-command
      set -g default-shell "${pkgs.fish}/bin/fish"

      # Make sure colors work in TUI apps
      # Works in tandem with fish/default.nix
      # See: https://gist.github.com/andersevenrud/015e61af2fd264371032763d4ed965b6
      set -g default-terminal 'tmux-256color'
      set -sg terminal-overrides ',*:RGB'

      # Force tmux to resize windows to the most recently active client
      set -g window-size latest
      setw -g aggressive-resize on

      # Unbind config edit since it's read-only anyway, and it messes up with overriden configs here
      unbind e

      # Rebind r to reload config
      unbind r
      bind r source-file ${config.home.homeDirectory}"/.config/tmux/tmux.conf"
    '';
  };
}
