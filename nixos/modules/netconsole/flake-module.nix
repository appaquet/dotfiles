{
  flake.modules.nixos.netconsole = {
    imports = [
      ./sender.nix
      ./receiver.nix
    ];
  };
}
