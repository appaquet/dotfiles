# TODO: DENDRITIC - Consider merging with restic-backup.nix when migrating to dendritic pattern
#
# Restic REST server module for receiving backups from clients.
# Wraps services.restic.server with sops-nix integration and Tailscale-only access.
{
  config,
  lib,
  ...
}:

let
  cfg = config.restic-server;
in
{
  options.restic-server = {
    enable = lib.mkEnableOption "Enable restic REST server";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/data/restic";
      description = "Directory for storing restic repositories";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port for restic REST server (Tailscale interface only when firewall enabled)";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file containing restic_server/htpasswd secret";
    };
  };

  config = lib.mkIf cfg.enable {
    # Sops secret for htpasswd file
    sops.secrets."restic_server/htpasswd" = {
      sopsFile = cfg.sopsFile;
      # htpasswd file needs to be readable by restic user
      owner = "restic";
      group = "restic";
    };

    # Restic REST server configuration
    services.restic.server = {
      enable = true;
      dataDir = cfg.dataDir;
      listenAddress = toString cfg.port;
      appendOnly = true;
      privateRepos = true;
      htpasswd-file = config.sops.secrets."restic_server/htpasswd".path;
    };

    # Firewall: only allow on Tailscale interface (if firewall is enabled)
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkIf config.networking.firewall.enable [
      cfg.port
    ];
  };
}
