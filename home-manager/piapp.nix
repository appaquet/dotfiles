{ inputs, ... }:

{
  imports = with inputs.self.modules.homeManager; [
    base
    agentic
    dev
  ];

  home.username = "appaquet";
  home.homeDirectory = "/home/appaquet";
  home.stateVersion = "25.11";

  # pb serves the SSH agent; its module comes from the private secrets flake.
  dotfiles.ssh.pb.enable = true;
}
