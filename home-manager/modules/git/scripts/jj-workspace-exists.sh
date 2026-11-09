# Exit 0 when a workspace with the given exact name exists.
if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  jj_usage 'Usage: jj-workspace-exists <workspace-name>'
fi

jj_has_workspace "$1"
