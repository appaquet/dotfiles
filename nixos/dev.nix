{ pkgs, inputs, ... }:

{
  imports = [
    inputs.vscode-server.nixosModule
  ];

  environment.systemPackages = with pkgs; [
    distrobox
    linuxPackages_latest.perf # perf
  ];

  # Automatically patches vscode-server nodejs
  # See https://github.com/nix-community/nixos-vscode-server
  services.vscode-server.enable = true;
}
