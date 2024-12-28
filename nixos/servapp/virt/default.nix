{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ../../virt.nix
    inputs.nixvirt.nixosModules.default
  ];

  virtualisation = {
    libvirt.enable = true;
    libvirt.connections = {
      "qemu:///system" = {
        domains = [
          {
            definition = ./domains/homeassistant.xml;
          }
          {
            definition = ./domains/pihole.xml;
          }
        ];
        pools = [
          {
            definition = ./pools/download.xml;
            active = true;
          }
        ];
      };
    };
  };

  # VMs ipv6 forward
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = "1";
  };

  # VMs aren't automatically starting since they require USB devices
  # that may not be mounted yet (see <https://github.com/NixOS/nixpkgs/issues/227636>)
  #
  # Also forward ipv6 to bridge devices
  systemd.services.virt-start-vms = {
    description = "Starts VMs after system fully booted";
    after = [ "display-manager.service" "libvirtd.service" ];
    requires = [ "display-manager.service" "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "start-vms" ''
        #!/run/current-system/sw/bin/bash
        
        ${pkgs.iptables}/bin/ip6tables -A FORWARD -i br0 -o br0 -j ACCEPT
        ${pkgs.iptables}/bin/ip6tables -A FORWARD -i br0 -j ACCEPT

        sleep 30 # Really make sure usb is ready

        ${pkgs.libvirt}/bin/virsh start homeassistant || true
        ${pkgs.libvirt}/bin/virsh start pihole || true
      ''}";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
