{ lib }:
{
  defaultExcludes = [
    ".cache"
    ".local/share/Trash"
    ".Trash"
    "Downloads"
    "node_modules"
    ".npm"
    ".cargo"
    ".rustup"
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

  defaultPruneOpts = [
    "--keep-hourly 24"
    "--keep-daily 7"
    "--keep-weekly 4"
    "--keep-monthly 12"
  ];

  # Secret names in sops yaml:
  #   restic/password - restic repository password
  #   restic/{hostname}-{name} - repository URL with credentials
  passwordSecret = "restic/password";
  repoSecret = hostname: name: "restic/${hostname}-${name}";

  # Generate sops.secrets for a backup
  mkSecrets =
    { hostname, sopsFile }:
    name: _backup: {
      "${lib.restic.repoSecret hostname name}" = {
        inherit sopsFile;
      };
    };

  # Base backup type options (shared between NixOS and home-manager)
  backupTypeOptions = {
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
  };
}
