{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.netconsole.sender;
in
{
  options.services.netconsole.listener = {
    enable = lib.mkEnableOption "Enable netconsole listener service";

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
    systemd.services.netconsole-listener = {
      description = "Netconsole listener service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.netcat}/bin/nc -luk ${toString cfg.port} | tee ${cfg.logFile}";
        Restart = "always";
      };
    };
  };
}
