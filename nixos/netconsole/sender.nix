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
  options.services.netconsole.sender = {
    enable = lib.mkEnableOption "Enable netconsole sender";

    interface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "Network interface to use for netconsole";
    };

    receiverIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.27"; # piapp
      description = "IP address of the log receiver machine";
    };

    receiverPort = lib.mkOption {
      type = lib.types.int;
      default = 6666;
      description = "UDP port on which the receiver listens";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelModules = [ "netconsole" ];
      # see https://www.kernel.org/doc/Documentation/networking/netconsole.txt
      extraModprobeConfig = ''
        options netconsole netconsole=@/${cfg.interface},${toString cfg.receiverPort}@${cfg.receiverIp}/
      '';
    };

    systemd.services.netconsole-enable = {
      description = "Re-enable netconsole after network setup";
      after = [ "network-setup.service" ];
      requires = [ "network-setup.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "start-netconsole" ''
          #!/run/current-system/sw/bin/bash

          export PATH=$PATH:/run/current-system/sw/bin

          dmesg -n 8
          rmmod netconsole || true
          modprobe netconsole || true
        ''}";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
