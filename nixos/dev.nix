{
  pkgs,
  inputs,
  config,
  ...
}:

{
  imports = [
    inputs.vscode-server.nixosModule
    inputs.cursor-server.nixosModule
  ];

  environment.systemPackages =
    (with pkgs; [
      distrobox
    ])
    ++ [
      config.boot.kernelPackages.perf # perf, aligned with current kernel version
    ];

  # Automatically patches vscode-server nodejs
  # See https://github.com/nix-community/nixos-vscode-server
  services.vscode-server.enable = true;
  services.cursor-server.enable = true;
}
