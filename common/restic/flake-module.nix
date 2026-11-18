{
  # Both surfaces back up clients: Home Manager renders wrapper scripts, NixOS schedules services.restic.backups. The
  # REST server receiving those backups is NixOS-only.
  flake.modules = {
    homeManager.restic = ./home/backup.nix;
    nixos.restic = {
      imports = [
        ./nixos/backup.nix
        ./nixos/server.nix
      ];
    };
  };
}
