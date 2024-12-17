{ pkgs, ... }:

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
  nasapp.shares = [
    {
      share = "backup_deskapp_vms";
      mount = backupMount;
    }
  ];

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
