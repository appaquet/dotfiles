{ pkgs, secrets, ... }:

let
  backupMount = "/mnt/deskapp_backup_vms";
  vmsDir = "/mnt/secondary/vms";

  backupScript = pkgs.writeShellScriptBin "backup-vms" ''
    set -xe

    VIRSH="${pkgs.libvirt}/bin/virsh"

    if [ "$(id -u)" -ne 0 ]; then
      echo "Please run as root"
      exit 1
    fi

    pushd ${vmsDir}

    # Dump vm domains & disk pools
    for vm in $($VIRSH list --all --name); do
      echo "Dumping ''${vm}.xml"
      $VIRSH dumpxml $vm > "''${vm}.xml"
    done

    for pool in $($VIRSH pool-list --name); do
      echo "Dumping ''${pool}.xml"
      $VIRSH pool-dumpxml $pool > "''${pool}-pool.xml"
    done

    # Fix perms
    chown -R qemu-libvirtd:libvirtd .
    chmod -R u+wr,g+wr,a+r .

    # Backup
    ${pkgs.rsync}/bin/rsync -av --progress --delete --whole-file --sparse . ${backupMount}/
  '';
in

{
  environment.systemPackages = [
    pkgs.cifs-utils
  ];

  fileSystems."${backupMount}" = {
    device = "//192.168.0.20/backup_deskapp_vms";
    fsType = "cifs";
    options =
      let
        automount_opts_list = [
          "vers=3.0"
          "uid=appaquet"
          "gid=users"
          # don't mount with fstab, but with systemd & make it resilient to network failures
          # from https://discourse.nixos.org/t/seeking-help-with-mounting-samba-cifs-behind-a-vpn-currently-using-autofs/35436/6
          "noauto"
          "x-systemd.automount"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "credentials=${secrets.deskapp.nasappCifs}"
        ];
        automount_opts = builtins.concatStringsSep "," automount_opts_list;
      in
      [ automount_opts ];
  };

  systemd.services."backup-vms" = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backupScript}/bin/backup-vms";
    };
  };

  systemd.timers."backup-vms" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Fri 21:00"; # Every Friday at 9:00 PM
      Unit = "backup-vms.service";
    };
  };
}
