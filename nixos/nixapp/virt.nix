{ pkgs, config, ... }:

{
  # See 
  # - https://nixos.wiki/wiki/Virt-manager
  # - https://www.reddit.com/r/NixOS/comments/ulzr88/creating_a_windows_11_vm_on_nixos_secure_boot/
  # - https://nixos.wiki/wiki/Libvirt
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
      runAsRoot = false;
      ovmf = {
        enable = true;
        packages = [ pkgs.OVMFFull.fd ]; # they will be accessible via /run/libvirt/nix-ovmf/
      };
    };
  };
  programs.virt-manager.enable = true;
  environment.systemPackages = [ pkgs.swtpm ];
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.appaquet = {
    extraGroups = [
      "libvirtd"
    ];
  };

  # Allow virsh to be run without password
  security.sudo = {
    extraRules = [{
      commands = [
        {
          command = "${config.system.path}/bin/virsh";
          options = [ "NOPASSWD" ];
        }
      ];
      groups = [ "wheel" ];
    }];
  };
}
