# USB Passthrough Persistence for libvirt VMs
#
# Solves the cold-start problem where USB devices aren't available when VM boots.
# Uses udev rules (hot-plug) + libvirt hooks (VM start) to attach devices.
#
# Debugging:
#   # Monitor udev events in real-time (plug/unplug USB)
#   udevadm monitor --property
#
#   # Test udev rule matching for a device
#   udevadm info -q path /dev/bus/usb/001/005
#   udevadm test /sys/bus/usb/devices/X-Y  # Replace X-Y with device path
#
#   # Watch handler script executions
#   journalctl -f | grep -i "usb\|libvirt\|qemu"
#
#   # Check libvirt hook executions
#   journalctl -u libvirtd -f
#
#   # Verify USB attachments on running VM
#   virsh dumpxml <vm> | grep -A5 hostdev
#   virsh qemu-monitor-command <vm> --hmp 'info usb'
#
#   # Manually test attach/detach
#   virsh attach-device <vm> /etc/libvirt/usb/<device>.xml --live
#   virsh detach-device <vm> /etc/libvirt/usb/<device>.xml --live
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.virtualisation.usbPassthrough;

  deviceType = lib.types.submodule {
    options = {
      vm = lib.mkOption {
        type = lib.types.str;
        description = "VM to passthrough the device to";
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the USB device";
      };

      vendor = lib.mkOption {
        type = lib.types.str;
        description = "USB device vendor ID";
      };

      product = lib.mkOption {
        type = lib.types.str;
        description = "USB device product ID";
      };
    };
  };

  optionsType = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable USB passthrough";
    };

    devices = lib.mkOption {
      type = lib.types.listOf deviceType;
      default = [ ];
      description = "List of devices to passthrough";
    };
  };

  mkUsbXml = device: ''
    <hostdev mode='subsystem' type='usb' managed='yes'>
      <source startupPolicy='optional'>
        <vendor id='0x${device.vendor}'/>
        <product id='0x${device.product}'/>
      </source>
    </hostdev>
  '';

  # Handles udev and libvirt hook events for attaching/detaching USB devices
  usbHandler = pkgs.writeShellScript "kvm-usb-handler" ''
    PATH=$PATH:${
      lib.makeBinPath [
        pkgs.libvirt
        pkgs.gnugrep
      ]
    }

    ACTION="$1"       # "attach" or "detach"
    XML_PATH="$2"     # Path to the XML definition
    VM="$3"           # Name of the VM

    # Check if VM is running
    if ! virsh list --name --state-running | grep -q "^$VM$"; then
      exit 0
    fi

    # Extract vendor ID from XML for duplicate checking
    VENDOR=$(grep -oP "vendor id='0x\K[^']+" "$XML_PATH" 2>/dev/null || echo "")

    if [ "$ACTION" == "attach" ]; then
      # Check if already attached by vendor ID
      if [ -n "$VENDOR" ] && virsh dumpxml "$VM" 2>/dev/null | grep -q "vendor id='0x$VENDOR'"; then
        exit 0
      fi
      virsh attach-device "$VM" "$XML_PATH" --live || true

    elif [ "$ACTION" == "detach" ]; then
      virsh detach-device "$VM" "$XML_PATH" --live || true
    fi
  '';

in
{
  options.virtualisation.usbPassthrough = optionsType;

  config = lib.mkIf cfg.enable {
    # 1. Create XML definitions in /etc/libvirt/usb/
    environment.etc = lib.foldl' (
      acc: dev:
      acc
      // {
        "libvirt/usb/${dev.name}.xml".text = mkUsbXml dev;
      }
    ) { } cfg.devices;

    # 2. Create Udev Rules
    # Note: ATTR{} works for add, but on remove the device is gone so we use ENV{PRODUCT}
    # ENV{PRODUCT} format is "vendor/product/bcdDevice" (without 0x prefix)
    services.udev.extraRules = lib.concatMapStrings (dev: ''
      SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="${dev.vendor}", ATTR{idProduct}=="${dev.product}", \
        RUN+="${usbHandler} attach '/etc/libvirt/usb/${dev.name}.xml' ${dev.vm}"
      SUBSYSTEM=="usb", ACTION=="remove", ENV{PRODUCT}=="${dev.vendor}/${dev.product}/*", \
        RUN+="${usbHandler} detach '/etc/libvirt/usb/${dev.name}.xml' ${dev.vm}"
    '') cfg.devices;

    # 3. Libvirt Hook (Solves the Boot Race Condition)
    # This runs when the VM transitions state. We catch "started".
    virtualisation.libvirtd.hooks.qemu = {
      "usb-autoplug" = pkgs.writeShellScript "qemu-hook-usb" ''
        OBJECT="$1"
        OPERATION="$2"

        if [ "$OPERATION" == "started" ]; then
          # Wait a moment for VM to stabilize
          sleep 2

          # Loop through our known XMLs and try to attach them
          ${lib.concatMapStrings (dev: ''
            if [ "$OBJECT" == "${dev.vm}" ]; then
              ${usbHandler} attach '/etc/libvirt/usb/${dev.name}.xml' ${dev.vm}
            fi
          '') cfg.devices}
        fi
      '';
    };
  };
}
