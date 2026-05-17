{ pkgs, lib, ... }:

let
  maybe-pre = pkgs.writeShellScriptBin "maybe-pre" ''
    if [ -f ".nono/pre.sh" ]; then
      . ".nono/pre.sh"
    fi
  '';

  maybe-in = pkgs.writeShellScriptBin "maybe-in" ''
    if [ -f ".nono/in.sh" ]; then
      . ".nono/in.sh"
    fi

    exec "$@"
  '';

  maybe-profile = pkgs.writeShellScriptBin "maybe-profile" ''
    DEFAULT="$1"
    if [ -f ".nono/profile.json" ]; then
      echo "$(pwd)/.nono/profile.json"
    else
      printf '%s' "$DEFAULT"
    fi
  '';

  maybe-portal = pkgs.writers.writePython3Bin "maybe-portal" {
    flakeIgnore = [
      "E501" # long lines
      "W503" # line break before binary operator
    ];
  } (builtins.readFile ./maybe-portal.py);

  maybe = pkgs.writeShellScriptBin "maybe" ''
    usage() {
      cat <<EOF
    Usage: maybe --profile <name> -- <cmd> [args...]

    Sources .nono/pre.sh if present, resolves the profile, conditionally adds the
    --allow-unix-socket grant when the maybe-portal approver is live, and execs
      nono run -- maybe-in <cmd> ...
    EOF
    }

    [ -f ".nono/pre.sh" ] && . ".nono/pre.sh"

    PROFILE=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -h|--help) usage; exit 0 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --)        shift; break ;;
        *)         echo "maybe: unexpected argument: $1" >&2; exit 2 ;;
      esac
    done
    [ -n "$PROFILE" ] || { echo "maybe: --profile is required" >&2; exit 2; }
    [ $# -gt 0 ]      || { echo "maybe: missing command after --" >&2; exit 2; }

    PROFILE=$(maybe-profile "$PROFILE")
    ARGS=(run --profile "$PROFILE" --allow-cwd)
    if [ -S ".nono/socket" ]; then
      ARGS+=(--allow-unix-socket .nono/socket)
    fi
    exec nono "''${ARGS[@]}" -- maybe-in "$@"
  '';
in
{
  home.packages = [
    maybe-pre
    maybe-in
    maybe-profile
    maybe-portal
    maybe
  ];
}
