{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.networking.myBridge;
in
{
  options.networking.myBridge = {
    enable = lib.mkEnableOption "Enable module";

    interface = lib.mkOption {
      type = lib.types.str;
      description = "Network interface";
    };

    lanIp = lib.mkOption {
      type = lib.types.str;
      description = "Lan IP";
    };

    lanPrefixLength = lib.mkOption {
      type = lib.types.int;
      default = 23;
      description = "Lan prefix length";
    };

    lanGateway = lib.mkOption {
      type = lib.types.str;
      description = "Lan gateway";
      default = "192.168.0.1";
    };

    lanNameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Lan name servers";
      default = [
        "192.168.0.1"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    networking.useDHCP = false;
    networking.bridges."br0".interfaces = [ cfg.interface ];
    networking.interfaces."br0".ipv4.addresses = [
      {
        address = cfg.lanIp;
        prefixLength = cfg.lanPrefixLength;
      }
    ];
    networking.defaultGateway = cfg.lanGateway;
    networking.nameservers = cfg.lanNameservers;

    # Attempt at fixing issue where network drops after switch
    # See https://github.com/NixOS/nixpkgs/issues/198267
    # Fix discussed here https://discourse.nixos.org/t/bridge-fails-for-one-boot-after-upgrade-to-24-05/46393
    networking.networkmanager.enable = false;

    # Enable IPv6 forwarding on the bridge for VMs
    boot.kernel.sysctl = {
      "net.ipv6.conf.all.forwarding" = "1";
      "net.ipv6.conf.all.accept_ra" = "2";
      "net.ipv6.conf.default.accept_ra" = "2";
    };

    # IPv6 forwarding iptables rules for the bridge
    systemd.services.bridge-ipv6-forward = {
      description = "Enable IPv6 forwarding on bridge";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "bridge-ipv6-forward" ''
          ${pkgs.iptables}/bin/ip6tables -A FORWARD -i br0 -o br0 -j ACCEPT
          ${pkgs.iptables}/bin/ip6tables -A FORWARD -i br0 -j ACCEPT
        ''}";
      };
    };
  };
}
