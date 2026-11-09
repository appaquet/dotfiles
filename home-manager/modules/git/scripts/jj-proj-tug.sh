# Move the project change of the current line onto a fresh @, then run `jj tug`.
#
# Both inspections read the working copy on purpose: an unsnapshotted edit must still
# count as content before deciding whether a child change is needed.
if [ "$(jj log --no-graph -r '@' -T 'empty')" = "false" ]; then
  jj new
fi

proj_change=$(jj log --no-graph -r 'heads(first_ancestors(@) & proj())' -T 'change_id.shortest()')
if [ -n "$proj_change" ]; then
  jj rebase -r "$proj_change" -B @
fi

jj tug
