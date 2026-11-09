# Remove a workspace from jj and its directory from disk.
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
  jj_usage 'Usage: jj-workspace-delete [workspace-name]'
fi

if ! name=$(jj-workspace-select "$@"); then
  exit 1
fi

if [ "$name" = "default" ]; then
  jj_usage 'Refusing to delete the default workspace'
fi

root=$(jj-workspace-path default)
if ! ws_root=$(jj-workspace-path "$name"); then
  echo "Could not resolve the path of workspace '$name'" >&2
  exit 1
fi
if [ ! -d "$ws_root" ]; then
  echo "Workspace '$name' directory not found: $ws_root" >&2
  echo "Untrack it manually with: jj workspace forget $name" >&2
  exit 1
fi

# Resolve the Herdr workspace before removing its worktree from disk.
wsid=""
if wt_json=$(herdr worktree list --json 2>/dev/null); then
  wsid=$(printf '%s' "$wt_json" \
    | jq -r --arg path "$ws_root" '[.result.worktrees[] | select(.path == $path) | .open_workspace_id] | .[0] // empty' \
    2>/dev/null || true)
fi

# Run from the default workspace so deleting the caller's workspace does not leave this
# process in a removed working directory.
cd "$root"
jj -R "$root" workspace remove "$name"

# Herdr may close the active shell, so this must remain the final step.
if [ -n "$wsid" ] && [ "$wsid" != "null" ]; then
  herdr worktree remove --workspace "$wsid" --force >/dev/null 2>&1 || true
fi
