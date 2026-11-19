{ inputs, ... }:

{
  imports = [
    inputs.secrets.homeManager.exomind
  ]
  ++ (with inputs.self.modules.homeManager; [
    base
    agentic
    dev
    docker
    media
    vms
    vpn
    work
  ]);

  dotfiles.nono.profiles.machine.filesystem.allow = [
    "$HOME/Projects"
    "$HOME/Work"
    "$HOME/.cache/dotcore"
  ];
  programs.direnv.config = {
    whitelist = {
      prefix = [
        "/home/appaquet/work/dotcore/dotcore"
      ];
    };
  };

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "23.11";
}
