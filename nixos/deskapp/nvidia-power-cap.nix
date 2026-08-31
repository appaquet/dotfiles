{ pkgs, config, ... }:

let
  # Watts. Device range on this card: min 400, max 600 (nvidia-smi -q -d POWER).
  gpuPowerLimitWatts = 500;

  applyPowerCap = pkgs.writeShellApplication {
    name = "apply-nvidia-power-cap";
    # Explicit tool set: systemd units get a minimal PATH, so every external command
    # used below (nvidia-smi, awk) must be in runtimeInputs.
    runtimeInputs = [
      config.hardware.nvidia.package.bin
      pkgs.gawk
    ];
    text = ''
      target=${toString gpuPowerLimitWatts}

      # Read the current limit and the device's allowed range in a single query.
      # Field names are hardware-verified and return decimal watts even with
      # nounits (e.g. "400.00, 600.00, 600.00").
      if ! limits=$(nvidia-smi --query-gpu=power.min_limit,power.max_limit,power.limit --format=csv,noheader,nounits 2>/dev/null); then
        # Benign skip when the dGPU is not bound to the NVIDIA driver (vfio gaming
        # mode): nvidia-smi fails there with "No devices were found".
        echo "No NVIDIA GPU available to cap (driver unbound or no devices); skipping"
        exit 0
      fi

      # Compare numerically (awk) because the values are floats, and skip the
      # write when the current limit already equals the target.
      verdict=$(awk -F, -v target="$target" '
        NR == 1 {
          target += 0
          minLimit = $1 + 0
          maxLimit = $2 + 0
          currentLimit = $3 + 0
          if (target < minLimit || target > maxLimit) {
            printf "ERROR: target power limit %gW is outside the device range %g-%gW\n", target, minLimit, maxLimit > "/dev/stderr"
            print "reject"
            exit
          }
          if (currentLimit == target) {
            print "skip"
            exit
          }
          print "apply"
        }
      ' <<< "$limits")

      case "$verdict" in
        reject)
          exit 1
          ;;
        skip)
          echo "NVIDIA power limit already at $target W"
          exit 0
          ;;
        apply)
          nvidia-smi -pl "$target"
          ;;
      esac
    '';
  };
in
{
  systemd.services.nvidia-power-cap = {
    description = "Apply NVIDIA GPU power limit";
    after = [ "switch-gpu-boot.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${applyPowerCap}/bin/apply-nvidia-power-cap";
    };
  };

  # Re-apply the cap after suspend/hibernate resume. nvidia-resume exists because
  # gpu-switch.nix sets powerManagement.enable = true with kernelSuspendNotifier = false.
  systemd.services.nvidia-resume.serviceConfig.ExecStartPost =
    "${applyPowerCap}/bin/apply-nvidia-power-cap";
}
