{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  networking.useDHCP = false;
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "154.12.116.85";
      prefixLength = 27;
    }
  ];
  networking.defaultGateway = "154.12.116.65";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
  networking.firewall.enable = false;

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  nix = {
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
      ];
    };
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNXBK1YpLeuIKx+tpVLpZOhKbMcqLeMx15SvcBG0jcR appaquet@gmail.com"
    ];
  };

  system.stateVersion = "25.11";
}
