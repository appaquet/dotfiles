# Shared helpers for the jj commands built into the jj-utils package. The build
# concatenates this file in front of one command body, so every command starts with
# strict shell options and shares one vocabulary for jj calls.

set -euo pipefail

# jj_usage <message> - report a usage or refusal message and exit non-zero.
jj_usage() {
  printf '%s\n' "$1" >&2
  exit 1
}

# jj_unquote - strip the quoting jj adds around names that need it.
jj_unquote() {
  sed 's/^"//; s/"$//'
}

# jj_commit_id <revset> - commit id of a single-revision revset, empty when nothing matches.
jj_commit_id() {
  jj --ignore-working-copy log --no-graph -r "$1" -T 'commit_id ++ "\n"'
}

# jj_bookmark_names <revset> - local bookmark names of one revision, comma-joined. The
# name-only template never carries jj's display marker for a bookmark that diverges from
# its remote, so no output post-processing is needed.
jj_bookmark_names() {
  jj --ignore-working-copy log --no-graph -r "$1" -T 'local_bookmarks.map(|b| b.name()).join(",")'
}

# jj_second_or_only_line - read stdin and print its second line, or its only line when it
# holds one. Stack lookups treat the single available entry as the previous one.
jj_second_or_only_line() {
  # cat, not head: a reader that exits early closes jj's stdout, and jj exits non-zero on
  # the broken pipe, which pipefail turns into a failed command.
  local lines second
  lines=$(cat)
  second=$(printf '%s\n' "$lines" | sed -n '2p')

  if [ -n "$second" ]; then
    printf '%s\n' "$second"
    return 0
  fi

  printf '%s\n' "$lines" | sed -n '1p'
}

# jj_workspace_names - workspace names, one per line, without jj's quoting.
jj_workspace_names() {
  jj workspace list --ignore-working-copy -T 'name ++ "\n"' | jj_unquote
}

# jj_has_workspace <name> - succeeds when a workspace with that exact name exists.
jj_has_workspace() {
  jj_workspace_names | grep -Fx -- "$1" >/dev/null
}

# jj_workspace_dir <name> - directory a new workspace gets, under the default workspace.
jj_workspace_dir() {
  printf '%s/.workspaces/%s\n' "$(jj-workspace-path default)" "$1"
}

# jj_resolve_or_create_workspace [name] - print the workspace name to open, creating the
# workspace first when a name is given and no such workspace exists yet.
jj_resolve_or_create_workspace() {
  if [ "$#" -eq 1 ] && [ -n "$1" ] && ! jj_has_workspace "$1"; then
    jj-workspace-add "$1" >&2
    printf '%s\n' "$1"
    return 0
  fi

  jj-workspace-select "$@"
}

# jj_diff_base <preferred-revset> <label> - commit id of the nearest safe diff base: the
# preferred revset when it is an ancestor of @, trunk() otherwise.
jj_diff_base() {
  local preferred_revset="$1"
  local preferred_label="$2"
  local base=""

  if [ -n "$preferred_revset" ]; then
    if ! base=$(jj_commit_id "($preferred_revset) & ::@"); then
      echo "Unable to resolve $preferred_label as a diff base." >&2
      return 1
    fi
  fi

  if [ -z "$base" ]; then
    if ! base=$(jj_commit_id 'trunk() & ::@'); then
      echo "Unable to resolve trunk() as a diff base." >&2
      return 1
    fi
  fi

  if [ -z "$base" ]; then
    echo "No safe diff base exists: neither $preferred_label nor trunk() is an ancestor of @. Rebase onto trunk or run jj diff --from <revision> --to @ explicitly." >&2
    return 1
  fi

  case "$base" in
    *$'\n'*)
      echo "Unable to select a single diff base from $preferred_label or trunk()." >&2
      return 1
      ;;
  esac

  printf '%s\n' "$base"
}
