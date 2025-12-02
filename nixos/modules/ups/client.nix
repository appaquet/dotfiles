{
  config,
  pkgs,
  lib,
  secrets,
  ...
}:

let
  cfg = config.power.myUps;

  mapNotifyFlags =
    listTypes: notification:
    map (typ: [
      typ
      notification
    ]) listTypes;
in

{
  options.power.myUps = {
    enable = lib.mkEnableOption "Enable UPS client listening after network UPS";

    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the UPS";
      default = "ups"; # ups (servers) or network
    };

    server = lib.mkOption {
      type = lib.types.str;
      description = "IP of the server";
      default = "192.168.0.11"; # piups
    };

    shutdownDelay = lib.mkOption {
      type = lib.types.int;
      description = "Shutdown after X seconds of UPS power";
      default = 0;
    };

    shutdownCmd = lib.mkOption {
      type = lib.types.str;
      description = "Shutdown command";
      default = "${pkgs.systemd}/bin/shutdown now";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        power.ups = {
          enable = true;
          mode = "netclient";

          users.monuser = {
            upsmon = "primary";
            passwordFile = secrets.upsPw;
          };

          upsmon = {
            settings = {
              MINSUPPLIES = 1;
              SHUTDOWNCMD = cfg.shutdownCmd;
              DEADTIME = 999999; # we don't want to stop if remote server becomes unavailable
              #DEBUG_MIN = 9;

              # Don't spam WALL, send to syslog + upssched
              NOTIFYFLAG = mapNotifyFlags [
                "ONLINE"
                "COMMOK"
                "COMMBAD"
                "NOCOMM"
                "NOPARENT"
                "ONBATT"
                "LOWBATT"
              ] "SYSLOG+EXEC";
            };

            monitor.main = {
              system = "${cfg.name}@${cfg.server}";
              user = "monuser";
              passwordFile = secrets.upsPw;
            };
          };
        };
      }

      (lib.mkIf (cfg.shutdownDelay > 0) {
        power.ups.schedulerRules = (import ./sched.nix { inherit config pkgs lib; }).outPath;
      })
    ]
  );
}
