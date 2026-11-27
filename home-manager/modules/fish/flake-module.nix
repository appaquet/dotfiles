{
  flake.modules.homeManager.fish = ./default.nix;

  perSystem =
    { pkgs, ... }:
    {
      checks.fish-monitor = import ./checks/fish-monitor.nix { inherit pkgs; };
    };
}
