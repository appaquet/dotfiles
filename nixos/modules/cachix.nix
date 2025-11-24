{ ... }:
{
  # used by darwin + nixos
  # update github workflows too when changing
  # to generate one, `cachix use <cache-name>` and copy the settings from ~/.config/nix/nix.conf
  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://nixos-raspberrypi.cachix.org"
        "https://numtide.cachix.org" # nix-ai-tools
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      ];
    };
  };
}
