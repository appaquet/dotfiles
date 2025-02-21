{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.netconsole.receiver;
in
{
  options.services.netconsole.receiver = {
    enable = lib.mkEnableOption "Enable netconsole receiver service";

    port = lib.mkOption {
      type = lib.types.int;
      default = 6666;
      description = "UDP port to listen for netconsole messages";
    };

    logFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/netconsole.log";
      description = "File where the logs are written";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.netconsole-receiver = {
      description = "Netconsole receiver service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "netconsole-receive" ''
          #!/run/current-system/sw/bin/bash

          export PATH=$PATH:/run/current-system/sw/bin

          echo "Listening..."
          nc -luk ${toString cfg.port} | tee ${cfg.logFile}
          echo "Done"
        ''}";

        Restart = "always";
      };
    };
  };
}
