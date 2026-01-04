{ config, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/claude
    ./modules/dev.nix
    ./modules/docker.nix
    ./modules/ghostty.nix
    ./modules/media.nix
    ./modules/mise.nix
    ./modules/restic/backup.nix
    ./modules/work
  ];

  dotfiles.neovim.devMode = true;

  restic-backup = {
    enable = true;
    hostname = "mbpapp";
    sopsFile = config.sops.secretsFiles.home;
    backups.home = {
      paths = [ "/Users/appaquet" ];
      exclude = [
        "Applications"
        "Library"
        "DocumentsApp"
        "Documents" # On iCloud, nothing important
        "Desktop" # On iCloud, nothing important
      ];
    };
  };

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "23.11";
}
