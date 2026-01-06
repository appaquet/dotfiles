{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.restic-backup;
  hostname = cfg.hostname;
  resticLib = import ../../../lib/restic.nix { inherit lib; };

  repoSecret = resticLib.repoSecret hostname;

  backupType = lib.types.submodule {
    options = resticLib.backupTypeOptions;
  };

  mkSecrets = name: _backup: {
    ${repoSecret name} = {
      sopsFile = cfg.sopsFile;
    };
  };

  # Wrapper script for restic commands (like NixOS createWrapper)
  mkResticWrapper =
    name: _backup:
    pkgs.writeShellScriptBin "restic-${hostname}-${name}" ''
      set -euo pipefail
      export PATH="${lib.makeBinPath [ pkgs.restic ]}:$PATH"
      export RESTIC_REPOSITORY=$(cat ${config.sops.secrets.${repoSecret name}.path})
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.${resticLib.passwordSecret}.path}
      exec restic "$@"
    '';

  # Backup script that uses the wrapper
  mkBackupScript =
    name: backup:
    let
      wrapper = mkResticWrapper name backup;
      excludeArgs = lib.concatMapStringsSep " " (p: "--exclude '${p}'") (
        (lib.optionals backup.excludeDefaults resticLib.defaultExcludes) ++ backup.exclude
      );
      excludeIfPresentArgs = lib.concatMapStringsSep " " (
        p: "--exclude-if-present '${p}'"
      ) resticLib.defaultExcludeIfPresent;
    in
    pkgs.writeShellScriptBin "restic-${hostname}-${name}-backup" ''
      set -euo pipefail

      # Initialize repo if needed (idempotent)
      ${wrapper}/bin/restic-${hostname}-${name} snapshots >/dev/null 2>&1 || ${wrapper}/bin/restic-${hostname}-${name} init

      # Run backup
      exec ${wrapper}/bin/restic-${hostname}-${name} backup \
        ${excludeArgs} \
        ${excludeIfPresentArgs} \
        ${lib.concatStringsSep " " (map lib.escapeShellArg backup.paths)} \
        "$@"
    '';

  mkReduScript =
    name: _backup:
    pkgs.writeShellScriptBin "redu-${hostname}-${name}" ''
      set -euo pipefail

      export PATH="${
        lib.makeBinPath [
          pkgs.restic
        ]
      }:$PATH"
      export RESTIC_REPOSITORY=$(cat ${config.sops.secrets.${repoSecret name}.path})
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.${resticLib.passwordSecret}.path}
      exec ${pkgs.redu}/bin/redu "$@"
    '';

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
          ${resticLib.passwordSecret} = {
            sopsFile = cfg.sopsFile;
          };
        }
      ]
      ++ (lib.mapAttrsToList mkSecrets cfg.backups)
    );

    home.packages =
      (lib.mapAttrsToList mkResticWrapper cfg.backups)
      ++ (lib.mapAttrsToList mkBackupScript cfg.backups)
      ++ (lib.mapAttrsToList mkReduScript cfg.backups);
  };
}
