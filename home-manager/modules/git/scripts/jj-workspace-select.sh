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

if ! name=$(jj_workspace_names | fzf --prompt 'Workspace > ' --height 40% --layout reverse --border); then
  exit 1
fi

if [ -z "$name" ]; then
  exit 1
fi

printf '%s\n' "$name"
