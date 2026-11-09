# Keep the current workspace's bookmark pointed at that workspace's working-copy commit.
# Creates the bookmark when absent, re-points it otherwise, and never touches a bookmark
# parked on a private change.
if [ "$#" -ne 0 ]; then
  jj_usage 'Usage: jj-workspace-branch'
fi

workspace=$(jj-workspace-name)

if [ "$workspace" = "default" ]; then
  jj_usage 'Refusing to manage a workspace bookmark in the default workspace'
fi

# Exact-match string pattern, so the workspace name matches no other bookmark.
bookmark_target=$(jj_commit_id "bookmarks(exact:\"${workspace}\")")

if [ -z "$bookmark_target" ]; then
  jj bookmark create "${workspace}"
  echo "Bookmark '${workspace}' created at @"
  exit 0
fi

# A bookmark parked on a private change (the `private()` revset alias) is deliberately
# positioned (see the `jj tug` alias) and is never re-pointed.
if [ -n "$(jj_commit_id "bookmarks(exact:\"${workspace}\") & private()")" ]; then
  echo "Bookmark '${workspace}' parked on a private change; not moving to @"
  exit 0
fi

working_commit=$(jj_commit_id '@')
if [ "$bookmark_target" = "$working_commit" ]; then
  echo "Bookmark '${workspace}' already at @"
  exit 0
fi

# @ can sit below or beside the bookmark's target after a rebase or a `jj tug`, so
# backwards moves must be allowed.
jj bookmark set "${workspace}" -r @ --allow-backwards
echo "Bookmark '${workspace}' moved to @"
