# NixOS restic backup module
# Uses services.restic.backups + systemd timers
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.restic-backup;
  hostname = config.networking.hostName;
  resticLib = import ../../../lib/restic.nix { inherit lib; };

  repoSecret = resticLib.repoSecret hostname;

  backupType = lib.types.submodule {
    options = resticLib.backupTypeOptions // {
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

  mkSecrets = name: _backup: {
    ${repoSecret name} = {
      sopsFile = cfg.sopsFile;
    };
  };

  mkReduWrapper =
    name: _backup:
    pkgs.writeShellScriptBin "redu-${hostname}-${name}" ''
      set -euo pipefail
      export PATH="${lib.makeBinPath [ pkgs.restic ]}:$PATH"
      export RESTIC_REPOSITORY=$(cat ${config.sops.secrets.${repoSecret name}.path})
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.${resticLib.passwordSecret}.path}
      exec ${pkgs.redu}/bin/redu "$@"
    '';

  mkBackup = name: backup: {
    name = "${hostname}-${name}";
    value = {
      initialize = true;

      repositoryFile = config.sops.secrets.${repoSecret name}.path;

      passwordFile = config.sops.secrets.${resticLib.passwordSecret}.path;

      paths = backup.paths;

      exclude = (lib.optionals backup.excludeDefaults resticLib.defaultExcludes) ++ backup.exclude;

      extraBackupArgs = map (f: "--exclude-if-present ${f}") resticLib.defaultExcludeIfPresent;

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
  options.restic-backup = {
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
      default = resticLib.defaultPruneOpts;
      description = "Default retention policy for restic forget";
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
          ${resticLib.passwordSecret} = {
            sopsFile = cfg.sopsFile;
          };
        }
      ]
      ++ (lib.mapAttrsToList mkSecrets cfg.backups)
    );

    services.restic.backups = builtins.listToAttrs (lib.mapAttrsToList mkBackup cfg.backups);

    environment.systemPackages = lib.mapAttrsToList mkReduWrapper cfg.backups;
  };
}
