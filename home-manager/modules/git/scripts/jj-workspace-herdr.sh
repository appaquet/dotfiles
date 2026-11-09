# Open a workspace as a Herdr worktree, creating the workspace if needed.
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
  jj_usage 'Usage: jj-workspace-herdr [workspace-name]'
fi

if ! herdr worktree list --json > /dev/null 2>&1; then
  jj_usage 'jjwh: cannot reach the herdr server; start herdr first'
fi

name=$(jj_resolve_or_create_workspace "$@")
default_root=$(jj-workspace-path default)
root=$(jj-workspace-path "$name")

if ! out=$(herdr worktree open --cwd "$default_root" --path "$root" --label "$name" --focus 2>&1); then
  echo "jjwh: failed to open workspace '$name' in herdr:" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
