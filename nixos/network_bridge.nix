{ inputs, lib, config, pkgs, ... }:

let
  cfg = config.networking.myBridge;
in
{

  options.myBridge = {
    enable = lib.mkEnableOption "Enable Module";

    interface = lib.mkOption {
      type = lib.types.string;
      description = "Network interface";
    };

    lanIp = lib.mkOption {
      type = lib.types.string;
      description = "Lan IP";
    };

    lanPrefixLength = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Lan prefix length";
    };

    lanGateway = lib.mkOption {
      type = lib.types.string;
      description = "Lan gateway";
    };

    lanNameservers = lib.mkOption {
      type = lib.listOf lib.types.string;
      description = "Lan name servers";
    };
  };


  config = lib.mkIf cfg.enable {
    networking.useDHCP = false;
    networking.bridges."br0".interfaces = [ cfg.interface ];
    networking.interfaces."br0".ipv4.addresses = [{
      address = cfg.lanIp;
      prefixLength = cfg.lanPrefixLength;
    }];
    networking.defaultGateway = cfg.lanGateway;
    networking.nameservers = cfg.lanNameservers;
  };

}
