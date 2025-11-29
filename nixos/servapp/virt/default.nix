{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/virt.nix
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

  systemd.services.virt-start-vms = {
    description = "Starts VMs after system fully booted";
    after = [
      "display-manager.service"
      "libvirtd.service"
    ];
    requires = [
      "display-manager.service"
      "libvirtd.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "start-vms" ''
        ${pkgs.libvirt}/bin/virsh start pihole || true
        ${pkgs.libvirt}/bin/virsh start homeassistant || true
      ''}";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
