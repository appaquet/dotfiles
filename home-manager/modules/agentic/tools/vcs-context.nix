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
    if ! workspace=$(
      jj workspace list --ignore-working-copy \
        -T 'name ++ "\t" ++ root ++ "\n"' \
        | awk -F '\t' -v current_root="$current_root" \
          '$2 == current_root && !found { print $1; found=1 }'
    ); then
      echo "Unable to list jj workspaces." >&2
      exit 1
    fi
    if [ -z "$workspace" ]; then
      echo "Unable to match the current jj workspace root to a workspace name." >&2
      exit 1
    fi

    if [ -n "$branch" ] && [ "$branch" != "$trunk" ]; then
      echo "Branch: $branch"
    fi
    echo "JJ workspace: $workspace"
  '';
}
