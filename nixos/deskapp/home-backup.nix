{ pkgs, secrets, config, ... }:

let
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
  ];
  excludeStr = builtins.concatStringsSep " " (map (x: "--exclude \"" + x + "\"") exclude);

  homePath = config.users.users.appaquet.home;
  folders = [
    "Work"
    "Projects"
    "etc"
    ".config"
    "dotfiles"
  ];
  foldersStr = builtins.concatStringsSep " " (map (x: "${homePath}/" + x) folders);

  backupMount = "/mnt/deskapp_backup";
  backupScript = pkgs.writeShellScriptBin "backup-home" ''
    set -x

    for FOLDER in ${foldersStr}; do
      echo "Syncing $FOLDER"
      ${pkgs.rsync}/bin/rsync -av --progress ${excludeStr} --delete --delete-excluded $FOLDER ${backupMount}/home/ || true
    done
  '';
in

{
  environment.systemPackages = [
    pkgs.cifs-utils
  ];

  fileSystems."${backupMount}" = {
    device = "//192.168.0.20/backup_deskapp";
    fsType = "cifs";
    options =
      let
        automount_opts_list = [
          "vers=2.0"
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
