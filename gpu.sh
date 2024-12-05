#!/bin/bash
set -x

# TODO: Move to a script written by nix
# TODO: Create a systemd service that switch to nvidia on boot
# TODO: Create a qemu hook to switch to vfio when starting a VM
# TODO: bullet proof the script (check if device already binded, PCI device identifier to bus address)

# lspci -nn | grep '10de:2216' | awk '{print $1}'
# 01:00.0



GPU="0000:01:00.0"
GPU_PCI="pci_0000_01_00_0"
AUDIO="0000:01:00.1"
AUDIO_PCI="pci_0000_01_00_1"

# function unbind() {
#     echo ""
# }

function nvidia() {
    echo "switching to nvidia..."

    # virsh nodedev-detach $GPU_PCI
    # virsh nodedev-detach $AUDIO_PCI

    echo $GPU >/sys/bus/pci/drivers/vfio-pci/unbind
    echo $AUDIO >/sys/bus/pci/drivers/vfio-pci/unbind

    sleep 5

    modprobe -a nvidia nvidia_modeset nvidia_uvm nvidia_drm

    sleep 5

    echo $GPU >/sys/bus/pci/drivers/nvidia/bind
    echo $AUDIO >/sys/bus/pci/drivers/nvidia/bind

    # modprobe -r vfio_pci vfio_iommu_type1 vfio
    # modprobe -a nvidia nvidia_modeset nvidia_uvm nvidia_drm

    # virsh nodedev-reattach $GPU_PCI
    # virsh nodedev-reattach $AUDIO_PCI
}

function vfio() {
    echo "switching to fvio..."

    echo $GPU >/sys/bus/pci/drivers/nvidia/unbind
    echo $AUDIO >/sys/bus/pci/drivers/nvidia/unbind

    echo $GPU >/sys/bus/pci/drivers/vfio-pci/bind
    echo $AUDIO >/sys/bus/pci/drivers/vfio-pci/bind
}

function attach() {
    modprobe -r nvidia
    modprobe -r nvidia_modeset
    modprobe -r nvidia_uvm
    modprobe -r nvidia_drm

    modprobe vfio_pci
    modprobe vfio_iommu_type1
    modprobe vfio

    virsh nodedev-reattach $GPU_PCI
    virsh nodedev-reattach $AUDIO_PCI

    # Unbind devices from VFIO
    # echo $GPU >/sys/bus/pci/drivers/vfio-pci/unbind
    # echo $AUDIO >/sys/bus/pci/drivers/vfio-pci/unbind

    # echo $GPU > /sys/bus/pci/devices/0000:01:00.0/driver/unbind
    # echo $AUDIO > /sys/bus/pci/devices/0000:01:00.1/driver/unbind

    # 10de:2216
    # 10de:1aef

    # echo "10de 2216" > /sys/bus/pci/drivers/nvidia/new_id
    # echo 0000:01:00.0 > /sys/bus/pci/drivers/nvidia/bind

    # echo $GPU >/sys/bus/pci/drivers_probe
    # echo $AUDIO >/sys/bus/pci/drivers_probe

    # modprobe -r vfio_pci
    # modprobe -r vfio_iommu_type1
    # modprobe -r vfio

    # virsh nodedev-reattach $GPU_PCI
    # virsh nodedev-reattach $AUDIO_PCI

    # # Load NVIDIA drivers
    # modprobe nvidia
    # modprobe nvidia_modeset
    # modprobe nvidia_uvm
    # modprobe nvidia_drm

}

$1

# Bind devices to NVIDIA driver
# 01:00.0 VGA compatible controller: NVIDIA Corporation GA102 [GeForce RTX 3080 Lite Hash Rate] (rev a1) (prog-if 00 [VGA controller])
#         Subsystem: Micro-Star International Co., Ltd. [MSI] Device 389b
#         Control: I/O+ Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR+ FastB2B- DisINTx-
#         Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
#         Latency: 0, Cache Line Size: 64 bytes
#         Interrupt: pin A routed to IRQ 182
#         IOMMU group: 13
#         Region 0: Memory at fa000000 (32-bit, non-prefetchable) [size=16M]
#         Region 1: Memory at f800000000 (64-bit, prefetchable) [size=16G]
#         Region 3: Memory at fc00000000 (64-bit, prefetchable) [size=32M]
#         Region 5: I/O ports at f000 [size=128]
#         Expansion ROM at fb000000 [disabled] [size=512K]
#         Capabilities: <access denied>
#         Kernel driver in use: vfio-pci
#         Kernel modules: nvidiafb, nouveau, nvidia_drm, nvidia

# 01:00.1 Audio device: NVIDIA Corporation GA102 High Definition Audio Controller (rev a1)
#         Subsystem: Micro-Star International Co., Ltd. [MSI] Device 389b
#         Control: I/O- Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR+ FastB2B- DisINTx-
#         Status: Cap+ 66MHz- UDF- FastB2B- ParErr- DEVSEL=fast >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
#         Latency: 0, Cache Line Size: 64 bytes
#         Interrupt: pin B routed to IRQ 183
#         IOMMU group: 13
#         Region 0: Memory at fb080000 (32-bit, non-prefetchable) [size=16K]
#         Capabilities: <access denied>
#         Kernel driver in use: vfio-pci
#         Kernel modules: snd_hda_intel
