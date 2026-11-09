# Open or focus a tmux window for a workspace, creating the workspace if needed.
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
  jj_usage 'Usage: jj-workspace-tmux [workspace-name]'
fi

if [ -z "${TMUX-}" ]; then
  jj_usage 'jjwt only works inside tmux'
fi

name=$(jj_resolve_or_create_workspace "$@")
root=$(jj-workspace-path "$name")

window_id=$(
  tmux list-windows -F '#{window_id}\t#{window_name}\t#{@jj_workspace_root}\t#{pane_current_path}' \
    | while IFS="$(printf '\t')" read -r id window_name workspace_root pane_path; do
        if [ "$window_name" = "$name" ] && { [ "$workspace_root" = "$root" ] || [ "$pane_path" = "$root" ]; }; then
          printf '%s\n' "$id"
          break
        fi
      done
)

if [ -n "$window_id" ]; then
  tmux select-window -t "$window_id"
else
  window_id=$(tmux new-window -P -F '#{window_id}' -c "$root" -n "$name")
  tmux set-window-option -t "$window_id" @jj_workspace_root "$root" >/dev/null
fi
