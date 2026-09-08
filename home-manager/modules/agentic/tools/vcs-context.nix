{ pkgs }:

pkgs.writeShellApplication {
  name = "agentic-vcs-context";

  runtimeInputs = with pkgs; [
    coreutils
    gawk
    git
    jujutsu
  ];

  text = ''
    if [ "$#" -ne 1 ]; then
      echo "Usage: agentic-vcs-context <jj|git>. Expected one of: jj, git" >&2
      exit 2
    fi

    case "$1" in
      jj)
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
        ;;
      git)
        if ! branch=$(git branch --show-current); then
          echo "Unable to determine the current Git branch." >&2
          exit 1
        fi
        if ! trunk_ref=$(git symbolic-ref refs/remotes/origin/HEAD); then
          echo "Unable to determine the Git trunk branch from origin/HEAD." >&2
          exit 1
        fi
        trunk="''${trunk_ref#refs/remotes/origin/}"

        if ! current_root=$(git rev-parse --show-toplevel); then
          echo "Unable to determine the current Git worktree root." >&2
          exit 1
        fi

        if [ -n "$branch" ] && [ "$branch" != "$trunk" ]; then
          echo "Branch: $branch"
        fi
        echo "Git worktree: $(basename "$current_root")"
        ;;
      *)
        echo "Unsupported VCS mode '$1'. Expected one of: jj, git" >&2
        exit 2
        ;;
    esac
  '';
}
