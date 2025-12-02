{ pkgs, config, ... }:

{
  # See
  # - https://nixos.wiki/wiki/Virt-manager
  # - https://www.reddit.com/r/NixOS/comments/ulzr88/creating_a_windows_11_vm_on_nixos_secure_boot/
  # - https://nixos.wiki/wiki/Libvirt
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore"; # don't resume running vms automatically
    onShutdown = "shutdown"; # cleanly shutdown VMs (not suspend) to avoid USB passthrough issues
    parallelShutdown = 10; # shutdown all VMs in parallel
    shutdownTimeout = 120; # wait max 120s per VM before force killing

    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
      runAsRoot = false;
    };
  };
  programs.virt-manager.enable = true;
  environment.systemPackages = [ pkgs.swtpm ];
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.appaquet = {
    extraGroups = [
      "libvirtd"
      "kvm"
    ];
  };

  # Allow virsh to be run without password
  security.sudo = {
    extraRules = [
      {
        commands = [
          {
            command = "${config.system.path}/bin/virsh"; # sudoers file wants explicit path
            options = [ "NOPASSWD" ];
          }
        ];
        groups = [ "wheel" ];
      }
    ];
  };

  # Shutdown all vms before suspend
  systemd.services.virt-pre-sleep-hook = {
    description = "Virt pre-sleep hook";
    wantedBy = [ "sleep.target" ]; # Trigger on any sleep state
    before = [ "sleep.target" ]; # Ensure it runs before sleep

    serviceConfig = {
      Type = "oneshot";
    };

    script = ''
      VIRSH="${pkgs.libvirt}/bin/virsh"
      for vm in `$VIRSH list --state-running --name`; do
        echo "Shutting down $vm..."
        $VIRSH shutdown $vm

        function is_running() {
          $VIRSH list --state-running --name | grep -q $1
        }

        function destroy() {
          $VIRSH destroy $1
        }

        # wait for it to shutdown
        ITER=0
        while is_running $vm; do
          if [ $ITER -gt 60 ]; then
            echo "VM $vm did not shutdown in time, destroying..."
            destroy $1
            exit 1
          fi  

          sleep 1
          ITER=$((ITER + 1))
        done

        echo "Successfully shut down $vm"
      done
    '';
  };
}
