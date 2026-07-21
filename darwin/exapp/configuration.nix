{ ... }:
{
  imports = [
    ../modules/common.nix
    ./apps.nix
  ];

  networking.localHostName = "exapp";
}
