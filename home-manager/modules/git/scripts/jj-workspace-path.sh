# Print the root directory of a workspace.
if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  jj_usage 'Usage: jj-workspace-path <workspace-name>'
fi

name="$1"
if root=$(jj workspace root --ignore-working-copy --name "$name" 2>/dev/null); then
  printf '%s\n' "$root"
  exit 0
fi

if [ "$name" != "default" ]; then
  echo "Workspace '$name' not found" >&2
  exit 1
fi

# Older repos record no root for the primary workspace, which also lives one level below
# the repository root in the legacy .workspaces layout.
candidate_root=$(jj workspace root --ignore-working-copy)
while [ "$(basename "$(dirname "$candidate_root")")" = ".workspaces" ]; do
  candidate_root=$(dirname "$(dirname "$candidate_root")")
done

if [ -d "$candidate_root/.jj/repo" ]; then
  printf '%s\n' "$candidate_root"
  exit 0
fi

echo "Workspace 'default' could not be resolved from legacy .workspaces layout" >&2
exit 1
