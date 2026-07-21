{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) attrNames filterAttrs mapAttrs' nameValuePair;
  datasets = config.nas.datasets;

  syncoidDatasets = attrNames (filterAttrs (_: ds: ds.vps_backup) datasets);
  offlineDatasets = attrNames (filterAttrs (_: ds: ds.offline_backup) datasets);
  noAutoSnapDatasets = filterAttrs (_: ds: !ds.autosnap) datasets;
in

{
  services.sanoid = {
    enable = true;

    datasets = {
      tank1 = {
        autosnap = true;
        autoprune = true;
        daily = 30;
        hourly = 0;
        monthly = 12;
        yearly = 0;
        recursive = true;
      };

      offline = {
        autosnap = false;
        autoprune = true;
        daily = 30;
        hourly = 0;
        monthly = 24;
        yearly = 0;
        recursive = true;
      };
    } // mapAttrs' (name: _: nameValuePair "tank1/${name}" { autosnap = false; }) noAutoSnapDatasets;
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

  systemd.services.offline-backup = {
    description = "Sync ZFS datasets to offline backup pool";
    path = [
      pkgs.sanoid
      pkgs.zfs
      config.systemd.package
    ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      ${lib.concatMapStringsSep "\n" (
        ds: "syncoid --no-sync-snap tank1/${ds} offline/${ds}"
      ) offlineDatasets}
      systemctl start sanoid.service
    '';
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
