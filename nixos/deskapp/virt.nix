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
        packages = [ pkgs.OVMFFull.fd ];
        # OR ?
        #packages = [
          #(pkgs.OVMF.override {
            #secureBoot = true;
            #tpmSupport = true;
          #}).fd
        #];
      };
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  # TODO: may not be needed, seems to be in /run/libvirt/nix-ovmf/
  environment.etc = {
    "ovmf/edk2-x86_64-secure-code.fd" = {
      source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-x86_64-secure-code.fd";
    };

    "ovmf/edk2-i386-vars.fd" = {
      source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-i386-vars.fd";
    };
  };

  programs.virt-manager.enable = true;
  environment.systemPackages = [ pkgs.swtpm ];
}
