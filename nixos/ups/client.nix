{
  config,
  pkgs,
  lib,
  secrets,
  ...
}:

let
  cfg = config.power.myUps;
in

{
  options.power.myUps = {
    enable = lib.mkEnableOption "Enable UPS client listening after network UPS";

    server = lib.mkOption {
      type = lib.types.str;
      description = "IP of the server";
      default = "192.168.0.27"; # piapp
    };

    shutdownDelay = lib.mkOption {
      type = lib.types.int;
      description = "Shutdown after X minutes of UPS power";
      default = 0;
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
              SHUTDOWNCMD = "${pkgs.systemd}/bin/shutdown now";
              DEADTIME = 999999; # we don't want to stop if remote server becomes unavailable

              # Don't spam WALL
              NOTIFYFLAG = [
                [
                  "COMMOK"
                  "SYSLOG"
                ]
                [
                  "COMMBAD"
                  "SYSLOG"
                ]
                [
                  "NOCOMM"
                  "SYSLOG"
                ]
                [
                  "NOPARENT"
                  "SYSLOG"
                ]
              ];
            };

            monitor.main = {
              system = "ups@${cfg.server}";
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
