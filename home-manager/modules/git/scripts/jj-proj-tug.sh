# Place the private project change directly below an empty working copy. By default,
# also tug the bookmarks after the rebase.
jj_proj_tug() {
  local project_only=false project working working_empty parents
  local project_revset='nearest_proj(@)'

  if [ "$#" -eq 1 ] && [ "$1" = '--project-only' ]; then
    project_only=true
  elif [ "$#" -ne 0 ]; then
    jj_usage 'Usage: jj-proj-tug [--project-only]'
  fi

  if [ "$project_only" = true ]; then
    # Even snapshotting dirty @ could rewrite a shared workspace or side descendant.
    project=$(jj_commit_id "$project_revset")
    working=$(jj_commit_id '@')
    check_project_tug "$project" "$working"
  fi

  working_empty=$(jj log --no-graph -r @ -T 'empty')
  project=$(jj_commit_id "$project_revset")
  working=$(jj_commit_id '@')
  if [ "$project_only" = true ]; then
    check_project_tug "$project" "$working"
    if [ "$working_empty" = true ]; then
      parents=$(jj_commit_id "parents(commit_id($working))")
      if [ "$parents" = "$project" ]; then
        echo 'Project change is already the parent of the empty working copy'
        return 0
      fi
    fi
  fi

  if [ "$working_empty" = false ]; then
    jj new
    working=$(jj_commit_id '@')
  fi

  if [ -n "$project" ]; then
    jj rebase --revision "commit_id($project)" --insert-before "commit_id($working)"
  fi

  if [ "$project_only" = false ]; then
    jj tug
  fi
}

# Refuse before snapshotting or rewriting a project stack shared with another line.
check_project_tug() {
  local project_id="$1" working_id="$2"
  local project="commit_id($project_id)" working="commit_id($working_id)"
  local unsafe other_workspaces

  [ -n "$project_id" ] || jj_usage 'No private project change found on the first-parent line'
  [ "$project_id" != "$working_id" ] || jj_usage 'The project change is the working copy; create a child first'

  # Cutting out the project would also remove its changes from side descendants.
  unsafe=$(jj_commit_id "($project:: ~ ::$working) | (merges() & $project::$working)")
  if [ -n "$unsafe" ]; then
    jj_usage 'Project-only tug requires a linear stack without merges or side descendants'
  fi

  other_workspaces=$(jj --ignore-working-copy log --no-graph -r "$project:: & working_copies()" \
    -T 'working_copies.filter(|ws| !ws.current_workspace()).map(|ws| ws.name() ++ "\n").join("")')
  if [ -n "$other_workspaces" ]; then
    jj_usage "Project-only tug would rewrite another workspace: $other_workspaces"
  fi
}

jj_proj_tug "$@"
