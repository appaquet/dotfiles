# Open a workspace in Herdr, creating the workspace and its Herdr space when needed.
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
  jj_usage 'Usage: jj-workspace-herdr [workspace-name]'
fi

if ! jj_herdr_core_available; then
  jj_usage 'jjwh: herdr-core (hc) is not installed on this host'
fi

name=$(jj_resolve_or_create_workspace "$@")
repo=$(jj-workspace-path default)
root=$(jj-workspace-path "$name")

space_id=$(jj_herdr_stable_space_id "$repo" "$name")

if ! terminals=$(jj_herdr_space_terminals "$space_id" "$root"); then
  jj_usage "jjwh: cannot ask herdr-core (hc) about workspace '$name'; is its core running?"
fi

if [ -n "$terminals" ]; then
  echo "jjwh: workspace '$name' is already open in Herdr" >&2
  exit 0
fi

# Herdr owns spaces, so the terminal itself carries the space it belongs to: the window adopts
# it into that space on its next listing, even when the window is closed or on another machine.
# No parent, so closing the shell that ran jjwh leaves the workspace terminal running.
if ! out=$(hc run --bg --keep --no-parent --cwd "$root" \
  --label "herdr.space=$space_id" 2>&1); then
  echo "jjwh: failed to start a terminal for workspace '$name' in Herdr:" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi

echo "jjwh: opened workspace '$name' in Herdr" >&2
