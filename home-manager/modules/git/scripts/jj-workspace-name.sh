# Print the name of the workspace serving this checkout.
if [ "$#" -ne 0 ]; then
  jj_usage 'Usage: jj-workspace-name'
fi

# jj marks the workspace serving this checkout as `(current)`; names with special
# characters (e.g. spaces) arrive quoted, so the quoting is stripped.
name=$(jj workspace list --ignore-working-copy | sed -n 's/^\(.*\) (current):.*/\1/p' | jj_unquote)

if [ -z "$name" ]; then
  echo "Unable to determine the current jj workspace." >&2
  exit 1
fi

printf '%s\n' "$name"
