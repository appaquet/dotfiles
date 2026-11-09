#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo "Usage: jj-workspace-branch" >&2
  exit 1
fi

current_root=$(jj workspace root --ignore-working-copy)

# jj records no root for the primary workspace of older repos (empty root column), so an
# unmatched root falls back to the single workspace without a recorded root.
if ! workspace=$(
  jj workspace list --ignore-working-copy -T 'name ++ "\t" ++ root ++ "\n"' \
    | awk -F '\t' -v current_root="$current_root" '
      $2 == current_root && !matched { matched = $1 }
      $2 == "" { unrooted_count++; unrooted = $1 }
      END {
        if (matched != "") print matched
        else if (unrooted_count == 1) print unrooted
      }'
); then
  echo "Unable to determine the current jj workspace." >&2
  exit 1
fi

if [ -z "$workspace" ] || [ "$workspace" = "default" ]; then
  echo "Refusing to create a workspace bookmark in the default workspace" >&2
  exit 1
fi

# Exact-match string pattern, so the workspace name matches no other bookmark.
matches=$(jj --ignore-working-copy log --no-graph \
  -r "bookmarks(exact:\"${workspace}\")" -T 'change_id')

if [ -n "$matches" ]; then
  echo "Bookmark '${workspace}' already exists"
  exit 0
fi

jj bookmark create "${workspace}"
echo "Bookmark '${workspace}' created at @"
