{
  config,
  ...
}:

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
