{ pkgs, ... }:

{
  home.file.".local/dotfiles_bin".source = ./bin;

  programs.fish = {
    interactiveShellInit = ''
      # Paths
      # We don't use the normal fish_user_paths because it slows down everything in the config.fish
      # See https://github.com/fish-shell/fish-shell/issues/2688
      set -x PATH ~/.local/dotfiles_bin $PATH
    '';
  };
}
