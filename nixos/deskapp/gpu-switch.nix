{ pkgs, config, ... }:

let
  # Keep in sync with ./virt/default.nix
  gpuPci = "10de:2b85";
  audioPci = "10de:22e8";

  # Runs the container stop and holder termination stages required before suspend.
  prepareNvidiaSuspend = pkgs.writeShellApplication {
    name = "prepare-nvidia-suspend";
    text = ''
      if ${stopNvidiaContainers}/bin/stop-nvidia-containers; then
        :
      else
        status=$?
        echo "ERROR: failed to stop NVIDIA containers before suspend" 1>&2
        exit "$status"
      fi

      if ${killNvidiaHolders}/bin/kill-nvidia-holders; then
        :
      else
        status=$?
        echo "ERROR: failed to kill NVIDIA device holders before suspend" 1>&2
        exit "$status"
      fi
    '';
  };

  # Finds and terminates NVIDIA device holders across mount namespaces, then requires
  # repeated scans to prove that no process has reopened a device.
  killNvidiaHolders = pkgs.writeShellApplication {
    name = "kill-nvidia-holders";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      config.virtualisation.docker.package
    ];

    text = ''
      deviceRoot=/dev
      sysfsRoot=/sys
      procRoot=/proc
      dryRun=false
      sleepCommand=${pkgs.coreutils}/bin/sleep
      dockerCommand=${config.virtualisation.docker.package}/bin/docker
      nvidiaDevices=()
      nvidiaDeviceRdevs=()
      holderPids=()
      holderDevices=()
      holderRdevs=()
      holderCgroups=()
      containerFile=""

      # Build matching path and rdev arrays for NVIDIA character and DRM render devices.
      refreshNvidiaDevices() {
        local -a devices=()
        local device drmDevice vendorFile statOutput major minor

        nvidiaDevices=()
        nvidiaDeviceRdevs=()

        if [ -d "$deviceRoot" ]; then
          mapfile -t devices < <(find "$deviceRoot" -xdev -type c -path "$deviceRoot/nvidia*" -print | sort -u)
        fi

        if [ -d "$deviceRoot/dri" ]; then
          while IFS= read -r device; do
            drmDevice=$(basename "$device")
            vendorFile="$sysfsRoot/class/drm/$drmDevice/device/vendor"
            if [ -r "$vendorFile" ] && [ "$(cat "$vendorFile")" = "0x10de" ]; then
              devices+=("$device")
            fi
          done < <(find "$deviceRoot/dri" -maxdepth 1 -type c -print)
        fi

        if (( ''${#devices[@]} > 0 )); then
          mapfile -t nvidiaDevices < <(printf '%s\n' "''${devices[@]}" | sort -u)
        fi
        for device in "''${nvidiaDevices[@]}"; do
          # %t/%T are the hex major:minor of device files, blank otherwise
          statOutput=$(stat -L -c '%t %T' "$device" 2>/dev/null) || statOutput=""
          read -r major minor <<< "$statOutput"
          if [[ "$major" =~ ^[0-9a-f]+$ && "$minor" =~ ^[0-9a-f]+$ ]]; then
            nvidiaDeviceRdevs+=("$major $minor")
          fi
        done
      }

      loadContainerNames() {
        containerFile=$(mktemp)
        # Best-effort: the container name is only used for log attribution
        "$dockerCommand" ps --no-trunc --format '{{.ID}} {{.Names}}' > "$containerFile" 2>/dev/null || : > "$containerFile"
      }

      containerNameForPid() {
        # Maps a PID to its docker container name when its cgroup is a docker scope
        local pid=$1 cgroup scope id line

        [ -r "$procRoot/$pid/cgroup" ] || return 0
        cgroup=$(tr '\n' ';' < "$procRoot/$pid/cgroup")
        [[ "$cgroup" =~ (docker-[0-9a-f]+)\.scope ]] || return 0
        scope="''${BASH_REMATCH[1]}"
        id="''${scope#docker-}"
        while IFS= read -r line; do
          # the scope carries the short (12-char) id; docker ps lists the full one
          [[ "$line" = "''${id}"* ]] && { printf '%s' "''${line#* }"; return 0; }
        done < "$containerFile"
        # Docker unavailable: fall back to the raw scope id
        printf '%s' "$id"
      }

      scanNvidiaHolders() {
        # Matches holder PIDs by device major:minor (rdev), so holders in other
        # mount namespaces whose nodes have different inodes are still found.
        # Returns 0 = holders found, 1 = no holders, >=2 = error.
        local errorFile statError index pid pidNum fd target targetStat
        local major minor rdevLabel matchDevice cgroup

        refreshNvidiaDevices

        holderPids=()
        holderDevices=()
        holderRdevs=()
        holderCgroups=()

        if (( ''${#nvidiaDevices[@]} == 0 )); then
          echo "No NVIDIA device nodes found under $deviceRoot"
          return 1
        fi

        errorFile=$(mktemp)
        statError=0

        # Container device nodes can have different inodes than their host nodes, so
        # inspect every process fd instead of relying on inode-based fuser/lsof matching.
        for pid in "$procRoot"/[0-9]*; do
          pidNum="''${pid##*/}"
          [ -d "$procRoot/$pidNum/fd" ] || continue
          for fd in "$procRoot/$pidNum/fd"/*; do
            [ -L "$fd" ] || continue
            target=$(readlink "$fd" 2>/dev/null) || continue
            # Only device paths can correspond to the NVIDIA nodes collected above.
            [[ "$target" = /dev/* ]] || continue

            matchDevice=""
            rdevLabel=""
            # Stat the open fd rather than its namespace-relative target path. The fd
            # resolves to the actual device across mount namespaces.
            if targetStat=$(stat -L -c '%t %T' "$fd" 2>>"$errorFile"); then
              read -r major minor <<< "$targetStat"
              if [[ "$major" =~ ^[0-9a-f]+$ && "$minor" =~ ^[0-9a-f]+$ ]]; then
                rdevLabel="$major $minor"
                for index in "''${!nvidiaDeviceRdevs[@]}"; do
                  if [ "''${nvidiaDeviceRdevs[$index]}" = "$rdevLabel" ]; then
                    matchDevice="''${nvidiaDevices[$index]}"
                    break
                  fi
                done
              fi
            else
              # A process can close an fd between readlink and stat. Only a persistent
              # fd that cannot be inspected makes the scan unsafe.
              [ -L "$fd" ] && statError=1
              continue
            fi
            [ -n "$matchDevice" ] || continue

            # Keep holder details in parallel arrays so each index describes one PID.
            holderPids+=("$pidNum")
            holderDevices+=("$matchDevice")
            holderRdevs+=("$rdevLabel")
            cgroup="unavailable"
            [ -r "$procRoot/$pidNum/cgroup" ] && cgroup=$(tr '\n' ';' < "$procRoot/$pidNum/cgroup")
            holderCgroups+=("$cgroup")
            break
          done
        done

        if (( statError > 0 )); then
          sort -u "$errorFile" | head -3 >&2
          rm -f "$errorFile"
          if (( ''${#holderPids[@]} == 0 )); then
            echo "ERROR: could not stat device paths while scanning for NVIDIA holders on: ''${nvidiaDevices[*]}" 1>&2
            return 2
          fi
        else
          rm -f "$errorFile"
        fi

        if (( ''${#holderPids[@]} > 0 )); then
          return 0
        fi

        return 1
      }

      logNvidiaHolders() {
        local index pid device state container

        for index in "''${!holderPids[@]}"; do
          pid="''${holderPids[$index]}"
          device="''${holderDevices[$index]}"
          state="unknown"
          if [ -r "$procRoot/$pid/stat" ]; then
            state=$(sed -E 's/^.*\) ([[:alnum:]]).*$/\1/' "$procRoot/$pid/stat")
          fi
          container=$(containerNameForPid "$pid")
          if [ -n "$container" ]; then
            echo "NVIDIA device holder: PID $pid device=$device rdev=''${holderRdevs[$index]} state=$state container=$container cgroup=''${holderCgroups[$index]}"
          else
            echo "NVIDIA device holder: PID $pid device=$device rdev=''${holderRdevs[$index]} state=$state cgroup=''${holderCgroups[$index]}"
          fi
        done
      }

      signalNvidiaHolders() {
        local signal=$1 pid

        for pid in "''${holderPids[@]}"; do
          # Processes exiting between scan and signal are not an error; the re-scan verifies
          kill "-$signal" "$pid" 2>/dev/null || true
        done
      }

      # A single empty scan can race a process reopening the GPU, so require a
      # continuous two-second interval with no holders before reporting success.
      verifyStableZeroUsers() {
        local status

        if scanNvidiaHolders; then
          echo "NVIDIA users reappeared while verifying holder termination on: ''${nvidiaDevices[*]}" 1>&2
          logNvidiaHolders 1>&2
          return 1
        else
          status=$?
          if (( status > 1 )); then
            return "$status"
          fi
        fi

        for _ in {1..4}; do
          "$sleepCommand" 0.5
          if scanNvidiaHolders; then
            echo "NVIDIA users appeared during the two-second stable-zero interval on: ''${nvidiaDevices[*]}" 1>&2
            logNvidiaHolders 1>&2
            return 1
          else
            status=$?
            if (( status > 1 )); then
              return "$status"
            fi
          fi
        done

        echo "NVIDIA devices have had no users for two seconds"
        return 0
      }

      # Apply a graceful TERM → bounded wait → KILL ladder, then verify stable zero.
      # Dry-run performs the same discovery but reports holders without signalling them.
      killNvidiaHolders() {
        local status attempt

        loadContainerNames

        if scanNvidiaHolders; then
          logNvidiaHolders
          if $dryRun; then
            echo "Dry run: ''${#holderPids[@]} NVIDIA device holder(s) found, no signals sent"
            return 3
          fi
          echo "Sending SIGTERM to NVIDIA device holders on: ''${nvidiaDevices[*]}"
        else
          status=$?
          if (( status > 1 )); then
            return "$status"
          fi
          verifyStableZeroUsers
          return
        fi

        signalNvidiaHolders TERM

        for attempt in {1..5}; do
          echo "Waiting for NVIDIA users to exit ($attempt/5)"
          "$sleepCommand" 1
          if scanNvidiaHolders; then
            continue
          else
            status=$?
            if (( status > 1 )); then
              return "$status"
            fi
          fi
          verifyStableZeroUsers
          return
        done

        echo "Sending SIGKILL to remaining NVIDIA device holders on: ''${nvidiaDevices[*]}"
        logNvidiaHolders
        signalNvidiaHolders KILL

        # Reaped asynchronously under load; give dying processes a moment so the
        # first verify scan does not mistake them for surviving holders
        "$sleepCommand" 1

        if verifyStableZeroUsers; then
          return 0
        else
          status=$?
          echo "ERROR: could not kill all NVIDIA device holders on: ''${nvidiaDevices[*]}" 1>&2
          if scanNvidiaHolders; then
            logNvidiaHolders 1>&2
          else
            status=$?
            if (( status > 1 )); then
              return "$status"
            fi
          fi
          return "$status"
        fi
      }

      for arg in "$@"; do
        case $arg in
          --dry-run)
            dryRun=true
            ;;
          *)
            echo "ERROR: unknown argument: $arg" 1>&2
            exit 2
            ;;
        esac
      done

      killNvidiaHolders
    '';
  };

  # Stops Docker workloads configured for NVIDIA access in two rounds. Any uncertain
  # result is nonzero so the suspend orchestrator aborts sleep.
  stopNvidiaContainers = pkgs.writeShellApplication {
    name = "stop-nvidia-containers";
    runtimeInputs = [
      pkgs.coreutils
      config.virtualisation.docker.package
      pkgs.gnugrep
      pkgs.jq
    ];
    text = ''
      dockerCommand=${config.virtualisation.docker.package}/bin/docker
      selectedContainers=()
      selectedNames=()

      # Docker can expose NVIDIA through CDI, runtime configuration, environment,
      # devices, binds, or mounts; inspect every running container for all forms.
      # Returns 0 when selected, 1 when none remain, and 2 on discovery errors.
      discoverNvidiaContainers() {
        local -a runningContainers=()
        local runningFile inspectFile selectedFile recheckFile id name status

        runningFile=$(mktemp)
        if ! "$dockerCommand" ps --quiet > "$runningFile"; then
          echo "ERROR: Docker failed to list running containers" 1>&2
          rm -f "$runningFile"
          return 2
        fi
        mapfile -t runningContainers < "$runningFile"
        rm -f "$runningFile"
        selectedContainers=()
        selectedNames=()
        if (( ''${#runningContainers[@]} == 0 )); then
          return 1
        fi

        # Collect selected id/name pairs in a file so jq output stays outside shell state.
        selectedFile=$(mktemp)
        for id in "''${runningContainers[@]}"; do
          # Inspect containers individually because one can exit while the scan is running.
          inspectFile=$(mktemp)
          if "$dockerCommand" inspect "$id" > "$inspectFile"; then
            if ! jq -r '
              # Direct NVIDIA device paths used by devices, binds, and mounts.
              def nvidiaPath:
                type == "string" and test("^/dev/nvidia");
              # Empty, none, and void explicitly disable NVIDIA visibility.
              def visibleNvidia:
                if type == "string" and startswith("NVIDIA_VISIBLE_DEVICES=") then
                  (ltrimstr("NVIDIA_VISIBLE_DEVICES=") | ascii_downcase) as $value |
                  $value != "" and $value != "none" and $value != "void"
                else
                  false
                end;
              # DeviceRequests covers the NVIDIA runtime, CDI ids, and GPU capabilities.
              def nvidiaRequest:
                ((.Driver // "") | ascii_downcase) == "nvidia" or
                ((.DeviceIDs // []) | any(.[]?; type == "string" and test("^nvidia\\.com/gpu(=|$)"))) or
                ((.Capabilities // []) | flatten | any(. == "gpu"));
              # Explicit Docker device mappings can name either side of the mapping.
              def directNvidiaDevice:
                ((.PathOnHost // "") | nvidiaPath) or
                ((.PathInContainer // "") | nvidiaPath);
              .[] |
              # Select when any supported Docker GPU exposure mechanism is present.
              select(
                ((.HostConfig.DeviceRequests // []) | any(.[]?; nvidiaRequest)) or
                ((.HostConfig.Runtime // "") | ascii_downcase) == "nvidia" or
                ((.Config.Env // []) | any(.[]?; visibleNvidia)) or
                ((.HostConfig.Devices // []) | any(.[]?; directNvidiaDevice)) or
                ((.HostConfig.Binds // []) | any(.[]?; nvidiaPath)) or
                ((.Mounts // []) | any(.[]?; ((.Source // "") | nvidiaPath) or ((.Destination // "") | nvidiaPath)))
              ) |
              [.Id, .Name] | @tsv
            ' "$inspectFile" >> "$selectedFile"; then
              echo "ERROR: could not select NVIDIA container from Docker inspection: $id" 1>&2
              rm -f "$inspectFile" "$selectedFile"
              return 2
            fi
            rm -f "$inspectFile"
            continue
          else
            status=$?
          fi

          # Inspect can race a normal container exit; re-check whether it still runs
          # before treating the failure as an unsafe Docker discovery error.
          rm -f "$inspectFile"
          if (( status != 1 )); then
            echo "ERROR: Docker inspect failed for running container $id" 1>&2
            rm -f "$selectedFile"
            return 2
          fi

          recheckFile=$(mktemp)
          if ! "$dockerCommand" ps --quiet > "$recheckFile"; then
            echo "ERROR: Docker failed to recheck running containers after inspect failure for $id" 1>&2
            rm -f "$recheckFile" "$selectedFile"
            return 2
          fi
          if grep -Fxq "$id" "$recheckFile"; then
            echo "ERROR: Docker inspect failed for running container $id" 1>&2
            rm -f "$recheckFile" "$selectedFile"
            return 2
          fi
          echo "NVIDIA container $id disappeared before inspection"
          rm -f "$recheckFile"
        done

        while IFS=$'\t' read -r id name; do
          [ -n "$id" ] || continue
          selectedContainers+=("$id")
          selectedNames+=("$name")
        done < "$selectedFile"
        rm -f "$selectedFile"

        if (( ''${#selectedContainers[@]} == 0 )); then
          return 1
        fi
      }

      # Stop selected containers concurrently so one 30-second timeout bounds the round.
      stopSelectedContainers() {
        local -a waitPids=()
        local -a outputFiles=()
        local index id name status

        for index in "''${!selectedContainers[@]}"; do
          id="''${selectedContainers[$index]}"
          name="''${selectedNames[$index]}"
          echo "Selected NVIDIA container $id ($name)"
          outputFiles+=("$(mktemp)")
          "$dockerCommand" stop --time 30 "$id" > "''${outputFiles[$index]}" 2>&1 &
          waitPids+=("$!")
        done

        for index in "''${!waitPids[@]}"; do
          id="''${selectedContainers[$index]}"
          name="''${selectedNames[$index]}"
          if wait "''${waitPids[$index]}"; then
            echo "Docker stop completed for $id ($name)"
          else
            status=$?
            echo "Docker stop exited $status for $id ($name):" 1>&2
            cat "''${outputFiles[$index]}" 1>&2
          fi
          rm -f "''${outputFiles[$index]}"
        done
      }

      # Re-discovery, rather than docker-stop exit codes, decides whether stopping succeeded.
      failForRunningNvidiaContainers() {
        local index status

        if discoverNvidiaContainers; then
          echo "ERROR: NVIDIA containers remain running after Docker stop:" 1>&2
          for index in "''${!selectedContainers[@]}"; do
            echo "  ''${selectedContainers[$index]} (''${selectedNames[$index]}) is still running" 1>&2
          done
          return 1
        else
          status=$?
          case $status in
            1) return 0 ;;
            *) return 2 ;;
          esac
        fi
      }

      # A second discovery/stop round catches containers that start or change while
      # the first round is waiting. Survivors after both rounds abort suspend.
      stopNvidiaContainers() {
        local round status

        for round in 1 2; do
          echo "Scanning Docker for NVIDIA containers (pass $round/2)"
          if discoverNvidiaContainers; then
            stopSelectedContainers
          else
            status=$?
            if (( status > 1 )); then
              return "$status"
            fi
          fi

          if failForRunningNvidiaContainers; then
            return 0
          else
            status=$?
            if (( status > 1 )); then
              return "$status"
            fi
          fi
        done

        # NVIDIA containers survived two stop rounds
        return 1
      }

      if stopNvidiaContainers; then
        :
      else
        status=$?
        echo "ERROR: stopping NVIDIA containers failed" 1>&2
        exit "$status"
      fi
    '';
  };

  # GPU switching script
  # Used in qemu hooks defined in `./virt/default.nix`
  gpuSwitch = pkgs.writeShellScriptBin "gpu-switch" ''
    #!/usr/bin/env bash
    set -uo pipefail

    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi

    export PATH="$PATH:/run/current-system/sw/bin/"

    function get_bus() {
        # takes a PCI device identifier (ex: 10de:2216) and returns the bus address (ex: 01:00.0)
        lspci -nn | grep "$1" | awk '{print $1}'
    }

    function format_bus() {
        # format bus address 01:00.0 to 0000:01:00.0
        echo "0000:$1"
    }

    function write_sysfs() {
        # Subshell contains any fd clobbering; timeout prevents infinite spin
        timeout 30 bash -c 'echo "$1" > "$2"' _ "$1" "$2"
    }

    function get_bus_driver() {
        # takes a bus address (ex: 0000:01:00.0) and returns the driver in use (ex: nvidia, vfio-pci)
        echo $(lspci -nn -s $1 -k | grep "Kernel driver in use" | awk '{print $5}')
    }

    function switch_driver() {
        to_driver=$1

        echo "Switching to $to_driver..."

        gpu_bus=$(format_bus $(get_bus "${gpuPci}"))
        audio_bus=$(format_bus $(get_bus "${audioPci}"))

        gpu_driver=$(get_bus_driver $gpu_bus)
        if [ "$gpu_driver" == "$to_driver" ]; then
            echo "GPU already using $to_driver driver"
            exit 0
        fi

        if [ "$gpu_driver" != "" ]; then
            echo "Unbinding GPU from $gpu_driver"
            write_sysfs "$gpu_bus" "/sys/bus/pci/drivers/$gpu_driver/unbind"
            write_sysfs "$audio_bus" "/sys/bus/pci/drivers/$gpu_driver/unbind" || true
            sleep 5
        fi

        # Force removal, otherwise drivers may not recognize the device (especially if it comes back from windows)
        echo "Removing GPU and audio devices"
        write_sysfs "1" "/sys/bus/pci/devices/$gpu_bus/remove" || true
        write_sysfs "1" "/sys/bus/pci/devices/$audio_bus/remove" || true
        sleep 5

        if [ "$to_driver" == "nvidia" ]; then
            echo "Loading nvidia drivers..."
            modprobe -r vfio_pci vfio vfio_iommu_type1
            modprobe -a nvidia nvidia_modeset nvidia_uvm nvidia_drm
            sleep 5
        elif [ "$to_driver" == "vfio-pci" ]; then
            echo "Loading vfio drivers..."
            # Re-check after PCI removal before unloading the NVIDIA modules.
            ${killNvidiaHolders}/bin/kill-nvidia-holders || exit $?
            rmmod nvidia_drm # modprobe -r doesn't seem to always work... order is important
            rmmod nvidia_uvm
            rmmod nvidia_modeset
            rmmod nvidia
            modprobe -a vfio_pci vfio vfio_iommu_type1
            sleep 5
        fi

        gpu_driver=$(get_bus_driver $gpu_bus)
        if [ "$gpu_driver" == "$to_driver" ]; then
            echo "Loading drivers bound to $to_driver automatically"
            exit 0
        fi

        echo "Rescanning PCI bus"
        write_sysfs "1" "/sys/bus/pci/rescan"

        sleep 5

        echo "Binding GPU to $to_driver"
        write_sysfs "$gpu_bus" "/sys/bus/pci/drivers/$to_driver/bind" || true
        write_sysfs "$audio_bus" "/sys/bus/pci/drivers/$to_driver/bind" || true

        sleep 5
    }

    function nvidia() {
        echo "Switching to nvidia driver..."

        # Remove vfio blacklist to allow nvidia modules to load
        rm -f /run/modprobe.d/nvidia-vfio-blacklist.conf

        switch_driver "nvidia"

        # Force drivers to persist, preventing high power usage on idle
        nvidia-smi -pm 1

        # Restart nvidia docker related stuff to make sure they get rebound
        systemctl reset-failed docker.service
        systemctl restart docker.socket
        systemctl restart docker.service
    }

    function vfio() {
        echo "Switching to vfio-pci driver..."

        if pgrep -x "process-compose" > /dev/null; then
            echo "Stopping process compose..."
            pkill process-compose || true
            sleep 10 # Give it time to stop
            pkill -9 process-compose || true
        fi

        # Blacklist nvidia modules to prevent udev/cdi-generator from loading them
        mkdir -p /run/modprobe.d
        echo "blacklist nvidia" > /run/modprobe.d/nvidia-vfio-blacklist.conf
        echo "blacklist nvidia_drm" >> /run/modprobe.d/nvidia-vfio-blacklist.conf
        echo "blacklist nvidia_modeset" >> /run/modprobe.d/nvidia-vfio-blacklist.conf
        echo "blacklist nvidia_uvm" >> /run/modprobe.d/nvidia-vfio-blacklist.conf

        # Nvidia containers will keep trying to use the nvidia driver if it's loaded
        # Leading to spammy errors in the logs. We don't need it while we're gaming anyway.
        systemctl stop nvidia-container-toolkit-cdi-generator.service
        systemctl stop docker.socket
        systemctl stop docker.service

        # Release every device holder before switch_driver starts PCI unbinding.
        ${killNvidiaHolders}/bin/kill-nvidia-holders || exit $?

        switch_driver "vfio-pci"
    }

    function status() {
        gpu_bus=$(format_bus $(get_bus "${gpuPci}"))
        gpu_driver=$(get_bus_driver $gpu_bus)
        echo "$gpu_driver"
    }

    CMD="''${1:-status}"
    shift
    $CMD "$@"
  '';
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
    gpuSwitch
    killNvidiaHolders
  ];

  system.build.nvidia-suspend-prepare = prepareNvidiaSuspend;

  systemd.services.switch-gpu-boot = {
    description = "Switch GPU to NVIDIA on boot";
    after = [
      "libvirtd.service"
      "display-manager.service" # prevent X from grabbing dGPU
    ];
    requires = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${gpuSwitch}/bin/gpu-switch nvidia";
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
      ExecStart = "${prepareNvidiaSuspend}/bin/prepare-nvidia-suspend";
      ExecStop = "${pkgs.writeShellScript "switch-gpu-after-resume" ''
        ${gpuSwitch}/bin/gpu-switch nvidia
      ''}";
    };
    requiredBy = [ "sleep.target" ];
  };
}
