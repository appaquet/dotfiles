{
  inputs,
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
}
