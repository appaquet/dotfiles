{
  inputs,
  ...
}:

{
  imports = [
    inputs.secrets.homeManager.exomind
    ./modules/base.nix
    ./modules/claude
    ./modules/dev.nix
    ./modules/ghostty.nix
  ];

  dotfiles.neovim.devMode = true;

  dotfiles.ssh-agent.defaultSocket = "/Users/appaquet/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "23.11";
}
