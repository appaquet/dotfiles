# Create a workspace under the default workspace's .workspaces directory.
if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  jj_usage 'Usage: jj-workspace-add <workspace-name>'
fi

name="$1"
if jj_has_workspace "$name"; then
  echo "Workspace '$name' already exists" >&2
  exit 1
fi

workspace_dir=$(jj_workspace_dir "$name")
mkdir -p "$(dirname "$workspace_dir")"
jj workspace add --colocate --name "$name" "$workspace_dir"
