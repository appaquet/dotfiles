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
      default = "192.168.0.28"; # piapp
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

    # We use a service to make sure netconsole is correctly started after network setup.
    #
    # Since we use a bridge, when booting, the network adapter isn't the same as when booted, and
    # the module refuses to mount. Also increasing verbosity so that we send more than just panics.
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
