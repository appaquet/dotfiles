{ pkgs, config, ... }:

let
  scripts = import ./scripts.nix {
    inherit pkgs;
    docker = config.virtualisation.docker.package;
  };
in
{
  # Enable both nvidia & amd drivers, even if nvidia won't be used for display. This allow
  # installing drivers.
  services.xserver.videoDrivers = [
    "nvidia"
    "amdgpu"
  ];

  # Prevent X from automatically binding the nvidia card. This allows the gpu-switch script to
  # manage it without fighting with X.
  services.xserver.serverFlagsSection = ''
    Option "AutoAddGPU" "false"
    Option "AutoBindGPU" "false"
  '';

  # From https://nixos.wiki/wiki/Nvidia
  hardware.nvidia = {
    # Hinders with dynamic switching since it manages the card using KMS
    # https://forums.developer.nvidia.com/t/unbinding-isolating-a-card-is-difficult-post-470/223134
    modesetting.enable = false;

    # Explicit suspend/resume services quiesce CUDA/UVM state and preserve VRAM.
    # Disable kernel notifiers to select the explicit /proc/driver/nvidia/suspend path.
    powerManagement = {
      enable = true;
      kernelSuspendNotifier = false;
      # Runtime D3 is unrelated to suspend-state preservation.
      finegrained = false;
    };

    open = true;

    nvidiaSettings = false; # no need for settings menu

    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # To test: docker run --rm -it --device=nvidia.com/gpu=all ubuntu:latest nvidia-smi
  hardware.nvidia-container-toolkit.enable = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    scripts.gpuSwitch
    scripts.killNvidiaHolders
  ];

  system.build.nvidia-suspend-prepare = scripts.prepareNvidiaSuspend;

  systemd.services.switch-gpu-boot = {
    description = "Switch GPU to NVIDIA on boot";
    after = [
      "libvirtd.service"
      "display-manager.service" # prevent X from grabbing dGPU
    ];
    requires = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${scripts.gpuSwitch}/bin/gpu-switch nvidia";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.nvidia-sleep-guard = {
    description = "Block sleep until NVIDIA users exit and restore the GPU on resume";

    # Keep the preparation oneshot active while sleeping; once sleep.target becomes unneeded
    # after resume, systemd stops it and runs ExecStop.
    # Container stopping and holder termination finish before NVIDIA snapshots driver state.
    before = [
      "nvidia-suspend.service"
      "sleep.target"
    ];

    unitConfig = {
      DefaultDependencies = false;
      StopWhenUnneeded = true;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Two 30s container-stop rounds plus holder termination can take ~80s; give
      # the scripts headroom so their own checks decide failure, not systemd.
      TimeoutStartSec = "120s";
      ExecStart = "${scripts.prepareNvidiaSuspend}/bin/prepare-nvidia-suspend";
      ExecStop = "${pkgs.writeShellScript "switch-gpu-after-resume" ''
        ${scripts.gpuSwitch}/bin/gpu-switch nvidia
      ''}";
    };
    requiredBy = [ "sleep.target" ];
  };
}
