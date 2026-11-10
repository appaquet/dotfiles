# Print the workspace name to operate on: the given one, or an interactive pick.
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
  jj_usage 'Usage: jj-workspace-select [workspace-name]'
fi

if [ "$#" -eq 1 ]; then
  if ! jj_has_workspace "$1"; then
    echo "Workspace '$1' not found" >&2
    exit 1
  fi

  printf '%s\n' "$1"
  exit 0
fi

workspaces=$(jj_workspace_names) || exit 1
current_workspace=$(jj-workspace-name) || exit 1

focus_args=()
position=1
while IFS= read -r workspace; do
  if [ "$workspace" = "$current_workspace" ]; then
    focus_args=(--bind "load:pos($position)")
    break
  fi
  position=$((position + 1))
done <<<"$workspaces"

if ! name=$(printf '%s\n' "$workspaces" | fzf --prompt 'Workspace > ' --height 40% --layout reverse --border "${focus_args[@]}"); then
  exit 1
fi

if [ -z "$name" ]; then
  exit 1
fi

printf '%s\n' "$name"
