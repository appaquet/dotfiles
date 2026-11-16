# Remove a workspace from jj, its directory from disk, and its Herdr space.
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

# Resolve the Herdr space's terminals while they still know their workspace folder. A failed
# query only costs the space close: the workspace is deleted either way.
space_id=$(jj_herdr_stable_space_id "$root" "$name")
addresses=$(jj_herdr_space_terminals "$space_id" "$ws_root") || addresses=""

# Run from the default workspace so deleting the caller's workspace does not leave this
# process in a removed working directory.
cd "$root"
jj -R "$root" workspace remove "$name"

# Ending a space's terminals closes its tabs, and a space closes with its last tab. Herdr may
# end the active shell, so this must remain the final step.
if [ -n "$addresses" ] && jj_herdr_core_available; then
  while IFS= read -r address; do
    [ -n "$address" ] || continue
    hc kill "$address" >/dev/null 2>&1 ||
      echo "jjwd: could not end terminal '$address' of the Herdr space of '$name'" >&2
  done <<<"$addresses"
fi
