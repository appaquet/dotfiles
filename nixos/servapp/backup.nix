{
  pkgs,
  ...
}:

let
  backupMount = "/mnt/backup_servapp";
  backupScript = pkgs.writeShellScriptBin "backup-home" ''
    set -x
    export PATH=/run/current-system/sw/bin:$PATH
    /home/appaquet/backup.sh
  '';
in

{
  nasapp.shares = [
    {
      share = "backup_servapp";
      mount = backupMount;
    }
  ];

  systemd.services."backup-home" = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backupScript}/bin/backup-home";
      User = "root";
    };
  };

  systemd.timers."backup-home" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Thu 03:00";
      Unit = "backup-home.service";
    };
  };
}
