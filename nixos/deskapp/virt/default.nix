{
  inputs,
  pkgs,
  lib,
  ...
}:

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

  # Keep in sync with ./gpu-switch.nix
  # Automatically switch to vfio driver when starting a VM
  # !Warning! You need to restart libvirtd if this script or gpu-switch changes
  systemd.services.libvirtd.preStart =
    let
      gpuDomains = [
        "win10"
        "embed"
      ];

      qemuHook = pkgs.writeScript "qemu-hook" ''
        #!${pkgs.stdenv.shell}

        GUEST_NAME="$1"
        OPERATION="$2"
        SUB_OPERATION="$3"

        GPU_DOMAINS=(
          ${lib.concatStringsSep " " gpuDomains}
        )

        if [[ ! " ''${GPU_DOMAINS[@]} " =~ " $GUEST_NAME " ]]; then
          exit 0
        fi

        if [[ "$OPERATION" == "prepare" ]]; then
          /run/current-system/sw/bin/gpu-switch vfio
        # elif [[ "$OPERATION" == "release" ]]; then
        #   /run/current-system/sw/bin/gpu-switch nvidia
        fi
      '';
    in
    ''
      mkdir -p /var/lib/libvirt/hooks
      chmod 755 /var/lib/libvirt/hooks

      # Copy hook files
      ln -sf ${qemuHook} /var/lib/libvirt/hooks/qemu
    '';
}
