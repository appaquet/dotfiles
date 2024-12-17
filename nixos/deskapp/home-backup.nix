{
  pkgs,
  secrets,
  config,
  ...
}:

let
  nasapp = import ../nasapp.nix { inherit pkgs; };

  exclude = [
    "_nosync"
    ".direnv"
    ".git"
    "target"
    "build"
    "data"
    "perf.data*"
    "venv"
    "bin"
    "node_modules"
    ".idea"
    "bench_data.local"
    "benches.data"
    "multilang.local"
    "downloads"
    "assets"
    "__debug_bin*"
  ];
  excludeStr = builtins.concatStringsSep " " (map (x: "--exclude \"" + x + "\"") exclude);

  homePath = config.users.users.appaquet.home;
  folders = [
    "Work"
    "Projects"
    "etc"
    ".config"
    "dotfiles"
    ".local"
  ];
  foldersStr = builtins.concatStringsSep " " (map (x: "${homePath}/" + x) folders);

  backupMount = "/mnt/deskapp_backup";
  backupScript = pkgs.writeShellScriptBin "backup-home" ''
    set -x

    for FOLDER in ${foldersStr}; do
      echo "Syncing $FOLDER"
      ${pkgs.rsync}/bin/rsync -av --progress ${excludeStr} --delete --delete-excluded --whole-file --sparse $FOLDER ${backupMount}/home/ || true
    done
  '';
in

{
  environment.systemPackages = [
    pkgs.cifs-utils
  ];

  fileSystems."${backupMount}" = smb.mkSmb { 
    share = "//192.168.0.20/backup_deskapp";
    uid = "appaquet";
    gid = "users";
    credentials = secrets.deskapp.nasappCifs;
  };

  systemd.services."backup-home" = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backupScript}/bin/backup-home";
      User = "appaquet";
    };
  };

  systemd.timers."backup-home" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "00/2:00"; # every 2 hours
      Unit = "backup-home.service";
    };
  };
}
