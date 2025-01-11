{
  pkgs,
  ...
}:

let
  backupMount = "/mnt/backup_servapp";
  backupScript = pkgs.writeShellScriptBin "backup-home" ''
    set -x
    export PATH=/run/current-system/sw/bin:$PATH

    for FOLDER in /home/appaquet/*; do
      if [ ! -f "$FOLDER/backup.sh" ]; then
        echo "Skipping $FOLDER"
        continue
      fi

      echo "Syncing $FOLDER..."
      ./$FOLDER/backup.sh
    done
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
