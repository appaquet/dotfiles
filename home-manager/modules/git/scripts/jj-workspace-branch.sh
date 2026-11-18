# Point the current workspace's bookmark at its latest non-empty, non-private change.
# Leave bookmarks deliberately parked on private changes alone.
if [ "$#" -ne 0 ]; then
  jj_usage 'Usage: jj-workspace-branch'
fi

workspace=$(jj-workspace-name)

if [ "$workspace" = "default" ]; then
  jj_usage 'Refusing to manage a workspace bookmark in the default workspace'
fi

# Snapshot before both lookups: local edits can make @ eligible, and Git
# integration can change where the existing bookmark points.
target=$(jj_commit_ids 'heads(::@ ~ (empty() | private()))')
bookmark_revset="bookmarks(exact:\"${workspace}\")"
private_target=$(jj_commit_id "$bookmark_revset & private()")
if [ -n "$private_target" ]; then
  echo "Bookmark '${workspace}' parked on a private change; not moving it"
  exit 0
fi

case "$target" in
  '') jj_usage "No non-empty, non-private change found in this workspace" ;;
  *$'\n'*) jj_usage "Multiple non-empty, non-private ancestors qualify; set the bookmark explicitly" ;;
esac

bookmark_target=$(jj_commit_id "$bookmark_revset")
short_target="${target:0:12}"
if [ -z "$bookmark_target" ]; then
  jj bookmark create "${workspace}" -r "commit_id($target)"
  echo "Bookmark '${workspace}' created at $short_target"
elif [ "$bookmark_target" = "$target" ]; then
  echo "Bookmark '${workspace}' already at $short_target"
else
  jj bookmark set "${workspace}" -r "commit_id($target)" --allow-backwards
  echo "Bookmark '${workspace}' moved to $short_target"
fi
