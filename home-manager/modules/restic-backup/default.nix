# Home-manager restic backup module (script-only, no scheduler)
# User sets up cron manually for scheduling.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.restic-backup;
  hostname = cfg.hostname;

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
  #   restic/{hostname}-{name} - repository URL with credentials
  passwordSecret = "restic/password";
  repoSecret = name: "restic/${hostname}-${name}";

  # Generate exclude arguments
  excludeArgs = lib.concatMapStringsSep " " (p: "--exclude '${p}'") defaultExcludes;
  excludeIfPresentArgs = lib.concatMapStringsSep " " (p: "--exclude-if-present '${p}'") defaultExcludeIfPresent;

  mkBackupScript = name: backup:
    pkgs.writeShellScriptBin "restic-${hostname}-${name}" ''
      set -euo pipefail

      export PATH="${lib.makeBinPath [ pkgs.restic ]}:$PATH"
      export RESTIC_REPOSITORY=$(cat ${config.sops.secrets.${repoSecret name}.path})
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.${passwordSecret}.path}

      # Initialize repo if needed (idempotent)
      restic snapshots >/dev/null 2>&1 || restic init

      # Run backup
      exec restic backup \
        ${excludeArgs} \
        ${excludeIfPresentArgs} \
        ${lib.concatMapStringsSep " " (p: "--exclude '${p}'") backup.exclude} \
        ${lib.concatStringsSep " " (map lib.escapeShellArg backup.paths)} \
        "$@"
    '';

  mkReduScript = name: _backup:
    pkgs.writeShellScriptBin "redu-${hostname}-${name}" ''
      set -euo pipefail

      export PATH="${lib.makeBinPath [ pkgs.restic ]}:$PATH"
      export RESTIC_REPOSITORY=$(cat ${config.sops.secrets.${repoSecret name}.path})
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.${passwordSecret}.path}

      exec ${pkgs.redu}/bin/redu "$@"
    '';

  mkSecrets = name: _backup: {
    ${repoSecret name} = {
      sopsFile = cfg.sopsFile;
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
    };
  };

in
{
  options.restic-backup = {
    enable = lib.mkEnableOption "restic backup scripts";

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname used in backup naming (required, no config.networking.hostName in home-manager)";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file containing restic secrets";
    };

    backups = lib.mkOption {
      type = lib.types.attrsOf backupType;
      default = { };
      description = "Backup jobs";
    };
  };

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

    home.packages =
      (lib.mapAttrsToList mkBackupScript cfg.backups)
      ++ (lib.mapAttrsToList mkReduScript cfg.backups);
  };
}
