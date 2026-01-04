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
    ./modules/restic-backup
    ./modules/work
  ];

  dotfiles.neovim.devMode = true;

  restic-backup = {
    enable = true;
    hostname = "mbpapp";
    sopsFile = config.sops.secretsFiles.home;
    backups.home.paths = [ "/Users/appaquet" ];
  };

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "23.11";
}
