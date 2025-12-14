{ pkgs, ... }:
{
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # Lots in humanfirst-dots as well
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  programs.jujutsu = {
    enable = true;

    # See https://github.com/jj-vcs/jj/blob/main/docs/config.md
    # Some goodies from https://zerowidth.com/2025/jj-tips-and-tricks/#bookmarks-and-branches
    # To see current + default config: `jj config list --include-defaults`
    settings = {
      user = {
        name = "Andre-Philippe Paquet";
        email = "appaquet@gmail.com";
      };

      ui = {
        paginate = "never";
        default-command = [
          "log"
          "--reversed"
        ];
      };

      git = {
      };

      revset-aliases = {
      };

      aliases = {
        "pull" = [
          "git"
          "fetch"
          "--all-remotes"
        ];
        "push" = [
          "git"
          "push"
        ];
        "e" = [
          "edit"
        ];
      };
    };
  };

  home.packages = with pkgs; [
    jjui
  ];
}
