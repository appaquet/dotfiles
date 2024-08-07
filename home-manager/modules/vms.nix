{ ... }:

{
  programs.fish = {
    shellAbbrs = {
      vm = "sudo virsh ";
      vmls = "sudo virsh list --all";
      vmstart = "sudo virsh start";
      vmstop = "sudo virsh shutdown";
    };
  };
}
