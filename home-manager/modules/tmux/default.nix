{ pkgs, ... }:

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

      # Loads gpakosz/.tmux configuration
      source-file ~/.tmux.conf

      # Synchronized panes
      bind S setw synchronize-panes\; display-message "Synchronized pane is now #{?synchronize-panes,on,off}"

      bind -r C-y swap-window -t -1 \; select-window -t -1  # swap current window with the previous one
      bind -r C-u swap-window -t +1 \; select-window -t +1  # swap current window with the next one

      # Fixes issue on macOS where shell in tmux is not right
      # See https://github.com/tmux/tmux/issues/4162
      set -gu default-command
      set -g default-shell "${pkgs.fish}/bin/fish"
    '';
  };
}
