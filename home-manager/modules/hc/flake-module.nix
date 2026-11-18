{
  # The herdr skills join the standalone agent instruction builds, the way hc/default.nix adds them to a home
  # configuration.
  dotfiles.agentic.instructionModules = [ ./skills.nix ];

  perSystem =
    { pkgs, ... }:
    {
      checks.status-bar-pace-unit = import ./checks/status-bar-pace-unit.nix { inherit pkgs; };
      checks.status-bar-sources-unit = import ./checks/status-bar-sources-unit.nix { inherit pkgs; };
    };
}
