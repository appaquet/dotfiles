# USB Passthrough Persistence for libvirt VMs
#
# Solves the cold-start problem where USB devices aren't available when VM boots.
# Uses udev rules (hot-plug) + libvirt hooks (VM start) to attach devices.
#
# Debugging:
#   # Monitor udev events in real-time (plug/unplug USB)
#   udevadm monitor --property
#
#   # Get sysfs path from lsusb device
#   udevadm info -q path /dev/bus/usb/BUS/DEV
#
#   # Watch for attach/detach via journalctl
#   journalctl -f | grep -i "usb\|kvm-usb"
#
#   # Verify USB attachments on running VM
#   virsh dumpxml <vm> | grep -A5 hostdev
#
#   # Manually test attach/detach
#   virsh attach-device <vm> /etc/libvirt/usb/<device>.xml --live
#   virsh detach-device <vm> /etc/libvirt/usb/<device>.xml --live
#
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
        description = "Name of the USB device (used for XML filename)";
      };

      vendor = lib.mkOption {
        type = lib.types.str;
        description = "USB device vendor ID (hex without 0x)";
      };

      product = lib.mkOption {
        type = lib.types.str;
        description = "USB device product ID (hex without 0x)";
      };
    };
  };

  optionsType = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable USB passthrough persistence";
    };

    devices = lib.mkOption {
      type = lib.types.listOf deviceType;
      default = [ ];
      description = "List of USB devices to passthrough";
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

  # Handler script for attaching/detaching USB devices
  usbHandler = pkgs.writeShellScript "kvm-usb-handler" ''
    PATH=$PATH:${lib.makeBinPath [ pkgs.libvirt pkgs.gnugrep pkgs.coreutils ]}

    ACTION="$1"
    XML_PATH="$2"
    VM="$3"
    LOGFILE="/tmp/kvm-usb-passthrough.log"

    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOGFILE" >&2; }

    log "Called: $ACTION $XML_PATH $VM"

    # Check if VM is running
    if ! timeout 5 virsh list --name --state-running 2>/dev/null | grep -q "^$VM$"; then
      log "VM $VM not running, skipping"
      exit 0
    fi

    # Extract vendor ID from XML for duplicate checking
    VENDOR=$(grep -oP "vendor id='0x\K[^']+" "$XML_PATH" 2>/dev/null || echo "")

    if [ "$ACTION" == "attach" ]; then
      # Skip if already attached
      if [ -n "$VENDOR" ] && timeout 5 virsh dumpxml "$VM" 2>/dev/null | grep -q "vendor id='0x$VENDOR'"; then
        log "Already attached (vendor $VENDOR), skipping"
        exit 0
      fi
      log "Attaching $XML_PATH to $VM"
      timeout 10 virsh attach-device "$VM" "$XML_PATH" --live 2>&1 | tee -a "$LOGFILE" || true

    elif [ "$ACTION" == "detach" ]; then
      log "Detaching $XML_PATH from $VM"
      timeout 10 virsh detach-device "$VM" "$XML_PATH" --live 2>&1 | tee -a "$LOGFILE" || true
    fi
  '';

in
{
  options.virtualisation.usbPassthrough = optionsType;

  config = lib.mkIf cfg.enable {
    # 1. XML definitions in /etc/libvirt/usb/
    environment.etc = lib.foldl' (
      acc: dev:
      acc // { "libvirt/usb/${dev.name}.xml".text = mkUsbXml dev; }
    ) { } cfg.devices;

    # 2. Udev rules for hot-plug
    # ATTR{} works for add, ENV{PRODUCT} for remove (device gone, no attrs)
    services.udev.extraRules = lib.concatMapStrings (dev: ''
      SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="${dev.vendor}", ATTR{idProduct}=="${dev.product}", \
        RUN+="${usbHandler} attach '/etc/libvirt/usb/${dev.name}.xml' ${dev.vm}"
      SUBSYSTEM=="usb", ACTION=="remove", ENV{PRODUCT}=="${dev.vendor}/${dev.product}/*", \
        RUN+="${usbHandler} detach '/etc/libvirt/usb/${dev.name}.xml' ${dev.vm}"
    '') cfg.devices;

    # 3. Libvirt hook for VM start
    # CRITICAL: Must not block - libvirt hooks are synchronous
    virtualisation.libvirtd.hooks.qemu = {
      "usb-autoplug" = pkgs.writeShellScript "qemu-hook-usb" ''
        OBJECT="$1"
        OPERATION="$2"

        if [ "$OPERATION" == "started" ]; then
          # Background to not block libvirt
          (
            sleep 5
            ${lib.concatMapStrings (dev: ''
              [ "$OBJECT" == "${dev.vm}" ] && ${usbHandler} attach '/etc/libvirt/usb/${dev.name}.xml' ${dev.vm}
            '') cfg.devices}
          ) &
        fi
      '';
    };
  };
}
