{
  config,
  inputs,
  ...
}:

{
  imports = [
    inputs.secrets.homeManager.exomind
  ]
  ++ (with inputs.self.modules.homeManager; [
    base
    agentic
    dev
    ghostty
  ]);

  dotfiles.restic.backup = {
    enable = true;
    hostname = "exapp";
    sopsFile = config.sops.secretsFiles.home;
    backups.home = {
      paths = [ "/Users/appaquet" ];
      exclude = [
        "Applications"
        "Library"
        "Documents" # On iCloud
        "Desktop" # On iCloud
        "Pictures" # On iCloud
      ];
    };
  };

  dotfiles.nono.profiles.machine.filesystem.allow = [
    "$HOME/exomind"
  ];
  programs.direnv.config = {
    whitelist = {
      prefix = [
        "/Users/appaquet/exomind"
      ];
    };
  };

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "25.11";
}
