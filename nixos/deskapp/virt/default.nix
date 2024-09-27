{ inputs, ... }:

{
  imports = [
    ../../virt.nix
    ../../virt-gpu-passthrough.nix
    inputs.nixvirt.nixosModules.default
  ];

  virtualisation = {
    gpuPassthrough = {
      enable = true;
      devices = [
        "10de:2216" # Graphics
        "10de:1aef" # Audio
      ];
    };

    libvirt.enable = true;
    libvirt.connections = {
      "qemu:///system" = {
        domains = [
          {
            definition = ./domains/embed.xml;
          }
          {
            definition = ./domains/win10.xml;
          }
        ];
        pools = [
          {
            definition = ./pools/secondary.xml;
            active = true;
          }
          {
            definition = ./pools/download.xml;
            active = true;
          }
        ];
      };
    };
  };
}
