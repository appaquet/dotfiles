{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.restic-backup;
  hostname = config.networking.hostName;

  modOptions = {
    restic-backup = {
      enable = lib.mkEnableOption "Enable restic backup to rest-server";

      sopsFile = lib.mkOption {
        type = lib.types.path;
        description = "Sops file containing restic secrets";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "hourly";
        description = "Default backup schedule (systemd calendar format)";
      };

      pruneOpts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--keep-hourly 24"
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 12"
        ];
        description = "Default retention policy for restic forget";
      };

      backups = lib.mkOption {
        type = lib.types.attrsOf backupType;
        default = { };
        description = ''
          Backup jobs.
        '';
      };
    };
  };

  backupType = lib.types.submodule {
    options = {
      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Paths to back up";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional exclude patterns (added to defaults)";
      };

      excludeDefaults = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include default exclude patterns";
      };

      schedule = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override default schedule";
      };

      pruneOpts = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Override default prune options";
      };
    };
  };

  defaultExcludes = [
    ".cache"
    ".local/share/Trash"
    ".Trash"
    "Downloads"
    "node_modules"
    ".npm"
    ".cargo/registry"
    ".cargo/git"
    "**/target/debug"
    "**/target/release"
    "__pycache__"
    ".venv"
    ".devenv"
    "*.pyc"
    "perf.data*"
  ];

  defaultExcludeIfPresent = [
    ".nobackup"
    ".nobackup.local"
  ];

  # Secret names in sops yaml:
  #   restic/password - restic repository password
  #   restic/{hostname}-{name} - repository URL with credentials (e.g., rest:http://user:pass@host:port/repo)
  passwordSecret = "restic/password";
  repoSecret = name: "restic/${hostname}-${name}";

  # sops.secrets declarations
  mkSecrets = name: _backup: {
    ${repoSecret name} = {
      sopsFile = cfg.sopsFile;
    };
  };

  mkReduWrapper =
    name: _backup:
    pkgs.writeShellScriptBin "redu-${hostname}-${name}" ''
      export PATH="${pkgs.restic}/bin:$PATH"
      export RESTIC_REPOSITORY=$(cat ${config.sops.secrets.${repoSecret name}.path})
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.${passwordSecret}.path}
      exec ${pkgs.redu}/bin/redu "$@"
    '';

  mkBackup = name: backup: {
    name = "${hostname}-${name}";
    value = {
      initialize = true;

      repositoryFile = config.sops.secrets.${repoSecret name}.path;

      passwordFile = config.sops.secrets.${passwordSecret}.path;

      paths = backup.paths;

      exclude = (lib.optionals backup.excludeDefaults defaultExcludes) ++ backup.exclude;

      extraBackupArgs = map (f: "--exclude-if-present ${f}") defaultExcludeIfPresent;

      pruneOpts = if backup.pruneOpts != null then backup.pruneOpts else cfg.pruneOpts;

      timerConfig = {
        OnCalendar = if backup.schedule != null then backup.schedule else cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };

      createWrapper = true;
    };
  };

in
{
  options = modOptions;

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.mkMerge (
      [
        {
          ${passwordSecret} = {
            sopsFile = cfg.sopsFile;
          };
        }
      ]
      ++ (lib.mapAttrsToList mkSecrets cfg.backups)
    );

    services.restic.backups = builtins.listToAttrs (lib.mapAttrsToList mkBackup cfg.backups);

    # Add redu wrappers for each backup (e.g., redu-deskapp-home)
    environment.systemPackages = lib.mapAttrsToList mkReduWrapper cfg.backups;
  };
}
