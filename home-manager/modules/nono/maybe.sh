usage() {
  cat <<EOF
Usage: maybe --profile <name> -- <cmd> [args...]

Sources .nono/pre.sh if present, resolves the profile, conditionally adds the
--allow-unix-socket grant when the maybe-portal approver is live and the
default Jujutsu workspace root when it can be resolved, and execs
  nono run -- maybe-in <cmd> ...
EOF
}

[ -f ".nono/pre.sh" ] && . ".nono/pre.sh"

PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --profile)
    PROFILE="$2"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "maybe: unexpected argument: $1" >&2
    exit 2
    ;;
  esac
done
[ -n "$PROFILE" ] || {
  echo "maybe: --profile is required" >&2
  exit 2
}
[ $# -gt 0 ] || {
  echo "maybe: missing command after --" >&2
  exit 2
}

PROFILE=$(maybe-profile "$PROFILE")
ARGS=(run --profile "$PROFILE" --allow-cwd --no-diagnostics)

if [ -S ".nono/socket" ]; then
  ARGS+=(--allow-unix-socket .nono/socket)
fi

# If we're in a jj workspace, allow the default workspace root.
# Prevents issue with jj commands need locking the workspace root.
if DEFAULT_WORKSPACE_ROOT=$(jj-workspace-path default 2>/dev/null); then
  [ -n "$DEFAULT_WORKSPACE_ROOT" ] && ARGS+=(--allow "$DEFAULT_WORKSPACE_ROOT")
fi

exec nono "${ARGS[@]}" -- maybe-in "$@"
