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
    mboxshell
    media
    vms
    vpn
  ]);

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";
}
