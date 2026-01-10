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

  dotfiles.ssh-agent.defaultSocket = "/Users/appaquet/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

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
