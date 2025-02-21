{
  config,
  lib,
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
  };
}
