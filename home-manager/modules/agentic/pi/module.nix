{
  config,
  inputs',
  lib,
  pkgs,
  ...
}:

let
  # This module owns the two user-facing commands and the mutable settings
  # handoff. Home Manager continues to own models, extensions, and other files.
  cfg = config.dotfiles.pi;
  jsonFormat = pkgs.formats.json { };

  environmentEntryType = lib.types.submodule {
    options = {
      value = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Literal environment variable value.";
      };

      file = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "File read at invocation time for the environment variable value.";
      };
    };
  };

  environmentAssertions =
    lib.mapAttrsToList (name: source: {
      assertion = builtins.match "[A-Za-z_][A-Za-z0-9_]*" name != null;
      message = "dotfiles.pi.environment contains invalid variable name ${name}.";
    }) cfg.environment
    ++ lib.mapAttrsToList (name: source: {
      assertion = (source.value != null) != (source.file != null);
      message = "dotfiles.pi.environment.${name} must define exactly one of value or file.";
    }) cfg.environment;

  # File-backed values are read by the wrapper so secret contents never enter
  # the Nix store or evaluation result.
  environmentScript = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: source:
      if source.value != null then
        "export ${name}=${lib.escapeShellArg source.value}"
      else
        let
          path = lib.escapeShellArg source.file;
        in
        ''
          if [ ! -r ${path} ]; then
            printf 'pi: cannot read environment file for %s: %s\n' ${lib.escapeShellArg name} ${path} >&2
            exit 1
          fi
          _pi_environment_value="$(cat ${path})"
          export ${name}="$_pi_environment_value"
          unset _pi_environment_value
        ''
    ) cfg.environment
  );

  settings = jsonFormat.generate "pi-settings.json" cfg.settings;

  # Pi owns runtime preferences in settings.json. Each launch preserves those
  # preferences while applying Nix-owned values with recursive precedence.
  piWrapper = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.flock
      pkgs.jq
    ];
    text = ''
      ${environmentScript}

      agent_dir="$HOME/.pi/agent"
      settings_file="$agent_dir/settings.json"
      lock_file="$agent_dir/.settings.json.lock"
      tmp_file=""

      cleanup() {
        if [ -n "$tmp_file" ]; then
          rm -f "$tmp_file"
        fi
      }
      trap cleanup EXIT HUP INT TERM

      umask 077
      mkdir -p "$agent_dir"
      touch "$lock_file"
      chmod 0600 "$lock_file"
      exec {settings_lock_fd}>"$lock_file"
      flock "$settings_lock_fd"

      if [ -e "$settings_file" ] && [ ! -f "$settings_file" ] && [ ! -L "$settings_file" ]; then
        printf 'pi: settings path is not a regular file: %s\n' "$settings_file" >&2
        exit 1
      fi

      if [ -f "$settings_file" ] && [ ! -L "$settings_file" ]; then
        if [ ! -r "$settings_file" ]; then
          printf 'pi: settings file is not readable: %s\n' "$settings_file" >&2
          exit 1
        fi
        if ! jq -s -e '(length == 1) and (.[0] | type == "object")' "$settings_file" >/dev/null; then
          printf 'pi: settings file must contain exactly one JSON object: %s\n' "$settings_file" >&2
          exit 1
        fi
      fi

      tmp_file="$(mktemp "$agent_dir/.settings.json.tmp.XXXXXX")"
      if [ -f "$settings_file" ] && [ ! -L "$settings_file" ]; then
        jq -s '.[0] * .[1]' "$settings_file" ${settings} >"$tmp_file"
      else
        printf '%s\n' '{}' | jq -s '.[0] * .[1]' - ${settings} >"$tmp_file"
      fi
      chmod 0600 "$tmp_file"

      if [ -L "$settings_file" ] || [ ! -f "$settings_file" ] || ! cmp -s "$tmp_file" "$settings_file"; then
        mv -T "$tmp_file" "$settings_file"
        tmp_file=""
      else
        chmod 0600 "$settings_file"
        rm -f "$tmp_file"
        tmp_file=""
      fi

      # The lock protects wrapper merges only. Pi must run without holding it
      # because the upstream process manages its own mutable state.
      flock -u "$settings_lock_fd"
      exec {settings_lock_fd}>&-
      trap - EXIT HUP INT TERM

      exec ${cfg.package}/bin/pi "$@"
    '';
  };

  # Sandboxed and direct launches share the same settings/environment wrapper.
  nonoPi = pkgs.writeShellScriptBin "nono-pi" ''
    export HERDR_AGENT=pi
    exec maybe --profile pi -- ${piWrapper}/bin/pi "$@"
  '';
in
{
  options.dotfiles.pi = {
    enable = lib.mkEnableOption "Pi coding-agent runtime integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs'.llm-agents.packages.pi.override { useBun = false; };
      description = "Upstream Pi package wrapped by the local runtime integration.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = jsonFormat.type;
      };
      default = { };
      description = "Nix-owned Pi settings recursively merged into mutable runtime settings.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf environmentEntryType;
      default = { };
      description = "Environment variables supplied to Pi as literals or runtime file reads.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = environmentAssertions;

    # Used by settings-drift extension to detect nix vs runtime settings drift
    dotfiles.pi.environment.PI_NIX_SETTINGS_FILE.value = toString settings;

    home.packages = [
      piWrapper
      nonoPi
    ];
  };
}
