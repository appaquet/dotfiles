{ pkgs }:

pkgs.writeShellApplication {
  name = "agentic-vcs-context";

  runtimeInputs = with pkgs; [
    coreutils
    gawk
    jujutsu
  ];

  text = ''
    if ! branch=$(jj --ignore-working-copy log --no-graph -r 'closest_bookmark(@)' \
      -T 'local_bookmarks.map(|b| b.name()).join(",")'); then
      echo "Unable to determine the current jj bookmark." >&2
      exit 1
    fi
    if ! trunk=$(jj --ignore-working-copy log --no-graph -r 'trunk()' \
      -T 'coalesce(local_bookmarks.map(|b| b.name()).join(","))'); then
      echo "Unable to determine the jj trunk bookmark." >&2
      exit 1
    fi

    if ! current_root=$(jj workspace root --ignore-working-copy); then
      echo "Unable to determine the current jj workspace root." >&2
      exit 1
    fi

    # jj records no root for the primary workspace of older repos (empty root column), so an
    # unmatched root falls back to the single workspace without a recorded root.
    if ! workspace=$(
      jj workspace list --ignore-working-copy \
        -T 'name ++ "\t" ++ root ++ "\n"' \
        | awk -F '\t' -v current_root="$current_root" '
          $2 == current_root && !matched { matched = $1 }
          $2 == "" { unrooted_count++; unrooted = $1 }
          END {
            if (matched != "") print matched
            else if (unrooted_count == 1) print unrooted
          }'
    ); then
      echo "Unable to list jj workspaces." >&2
      exit 1
    fi

    if [ -n "$branch" ] && [ "$branch" != "$trunk" ]; then
      echo "Branch: $branch"
    fi

    if [ -n "$workspace" ]; then
      echo "JJ workspace: $workspace"
    else
      echo "Unable to match the current jj workspace root to a workspace name." >&2
    fi
  '';
}
