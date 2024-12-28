{ pkgs, ... }:

let
  # See https://stackoverflow.com/questions/53658303/fetchfromgithub-filter-down-and-use-as-environment-etc-file-source
  dotTmuxRepo = pkgs.fetchFromGitHub {
    owner = "gpakosz"; # https://github.com/gpakosz/.tmux
    repo = ".tmux";
    rev = "5f1047550ba2ba16a27bf8c9ea958fbbf974598d";
    sha256 = "sha256-rsqNQE7XBSzHsXqx2Cl9B8p8FyrhQYUoQSCj5teHSFk";
    stripRoot = false;
  };

  dotTmuxConfFile = "${dotTmuxRepo}/.tmux-5f1047550ba2ba16a27bf8c9ea958fbbf974598d/.tmux.conf";
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
      bind e setw synchronize-panes\; display-message "Synchronized pane is now #{?synchronize-panes,on,off}"

      # Fixes issue on macOS where shell in tmux is not right
      # See https://github.com/tmux/tmux/issues/4162
      set -gu default-command
      set -g default-shell "${pkgs.fish}/bin/fish"
    '';
  };
}
