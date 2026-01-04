# Restic REST server module for receiving backups from clients.
# Wraps services.restic.server with sops-nix integration and Tailscale-only access.
{
  config,
  lib,
  pkgs,
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

    appendOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable append-only mode (prevents deletion from clients)";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."restic_server/htpasswd" = {
      sopsFile = cfg.sopsFile;
      owner = "restic";
      group = "restic";
    };

    services.restic.server = {
      enable = true;

      dataDir = cfg.dataDir;

      listenAddress = toString cfg.port;

      appendOnly = cfg.appendOnly;

      privateRepos = true; # per-user repository (username/repo)

      htpasswd-file = config.sops.secrets."restic_server/htpasswd".path;
    };

    # Only allow on Tailscale interface (if firewall is enabled)
    networking.firewall.interfaces."tailscale0".allowedTCPPorts =
      lib.mkIf config.networking.firewall.enable
        [
          cfg.port
        ];

    environment.systemPackages = with pkgs; [
      restic
    ];
  };
}
