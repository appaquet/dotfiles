{
  config,
  lib,
  ...
}:

let
  syncoidDatasets = lib.attrNames (lib.filterAttrs (_: ds: ds.vps_backup) config.nas.datasets);
in

{
  services.sanoid = {
    enable = true;

    datasets."tank1" = {
      autosnap = true;
      autoprune = true;
      daily = 30;
      hourly = 0;
      monthly = 12;
      yearly = 0;
      recursive = true;
    };
  };

  sops.secrets."syncoid/ssh_key" = {
    sopsFile = config.sops.secretsFiles.servapp;
    owner = "root";
    mode = "0400";
  };

  services.syncoid = {
    enable = true;
    user = "root";
    interval = "*-*-* 03:00:00";
    sshKey = config.sops.secrets."syncoid/ssh_key".path;
    commonArgs = [ "--no-sync-snap" ];
    commands = lib.genAttrs syncoidDatasets (ds: {
      source = "tank1/${ds}";
      target = "root@vps.n3x.net:datapool/backup-servapp/${ds}";
      sendOptions = "w";
      extraArgs = [
        "--sshport=22222"
        "--sshoption=StrictHostKeyChecking=off"
        "--sshoption=UserKnownHostsFile=/dev/null"
      ];
    });
  };

  restic-backup = {
    enable = true;
    sopsFile = config.sops.secretsFiles.home;

    backups.home = {
      paths = [ "/home/appaquet" ];
      schedule = "daily";
    };
  };

  restic-server = {
    enable = true;
    dataDir = "/data/backup_restic";
    sopsFile = config.sops.secretsFiles.servapp;
  };
}
