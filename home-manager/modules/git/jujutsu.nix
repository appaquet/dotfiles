{ pkgs, ... }:
{
  programs.jujutsu = {
    enable = true;

    # See https://github.com/jj-vcs/jj/blob/main/docs/config.md
    # Some goodies from https://zerowidth.com/2025/jj-tips-and-tricks/#bookmarks-and-branches
    # To see current + default config: `jj config list --include-defaults`
    settings = {
      user = {
        name = "Andre-Philippe Paquet";
        email = "appaquet@gmail.com";
      };

      snapshot = {
        auto-update-stale = true; # Automatically update stale workspaces
      };

      ui = {
        paginate = "never";
        default-command = [
          "log"
          "--reversed"
        ];
      };

      git = {
        private-commits = "private()"; # prevent pushing private commits
      };

      revset-aliases = {
        "proj()" = "description(glob:'private: proj*')";
        "closest_bookmark(to)" = "heads(::to & bookmarks())";
        "recent()" = "committer_date(after:\"1 months ago\")";
        "private()" = "description(glob:'private:*')";
        "agent()" = "description(glob:'private: agent:*') | description(glob:'private: claude:*')";
      };

      aliases = {
        "pull" = [
          "git"
          "fetch"
          "--all-remotes"
        ];
        "push" = [
          "git"
          "push"
        ];
        "e" = [
          "edit"
        ];
        "ls" = [
          "util"
          "exec"
          "--"
          "bash"
          "-c"
          ''
            jj log --limit 5
            echo ""
            jj status
          ''
          ""
        ];

        # Move current branch onto the most most recent non-private bookmark
        "tug" = [
          "bookmark"
          "move"
          "--from"
          "heads(::@- & bookmarks())"
          "--to"
          "heads(::@- & ~private())"
          "--allow-backwards"
        ];

        # Rebase current branch onto trunk with support for multi-parents
        "rebase-trunk" = [
          "rebase"
          "-s"
          "roots(trunk()..@)" # root of any branches that leads us to trunk allowing support for multi-parents
          "-d"
          "trunk()" # rebase on trunk
        ];

        # Squash consecutive working changes (agent-authored, empty, undescribed) into @
        "squash-working" = [
          "squash"
          "--from"
          "(trunk()..@) & latest((trunk()..@) & ~(empty() | agent() | description(exact:'')))..(@- & (empty() | agent() | description(exact:'')))"
          "--to"
          "@"
        ];
      };
    };
  };

  home.packages = with pkgs; [
    jjui
    (writeShellScriptBin "jj-proj-tug" ''
      set -euo pipefail

      if [ "$(jj log --no-graph -r '@' -T 'empty')" = "false" ]; then
        jj new
      fi
      PROJ=$(jj log --no-graph -r 'heads(first_ancestors(@) & proj())' -T 'change_id.shortest()')
      if [ -n "$PROJ" ]; then
        jj rebase -r "$PROJ" -B @
      fi

      jj tug
    '')
    (writeShellScriptBin "jj-main-branch" ''
      jj log --no-graph -r 'trunk()' -T 'coalesce(local_bookmarks)'
    '')
    (writeShellScriptBin "jj-current-branch" ''
      jj --ignore-working-copy log --no-graph -r "closest_bookmark(@)" -T 'local_bookmarks.map(|b| b.name()).join(",")'
    '')
    (writeShellScriptBin "jj-prev-branch" ''
      jj-stacked-branches | head -n 2 | tail -n 1
    '')
    (writeShellScriptBin "jj-diff-working" ''
      jj diff -r "$(jj-current-branch)..@" "$@"
    '')
    (writeShellScriptBin "jj-diff-branch" ''
      jj diff -r "$(jj-prev-branch)..@" "$@"
    '')
    (writeShellScriptBin "jj-stacked-branches" ''
      jj log --no-graph -r '(trunk()..@ | trunk()) & bookmarks()' -T 'coalesce(local_bookmarks) ++ "\n"' | sed 's/ *\*$//'
    '')
    (writeShellScriptBin "jj-stacked-stats" ''
      if [ -n "$1" ]; then
          from="$1"
      else
          from="trunk()"
      fi
      trunk=$(jj-main-branch)
      echo "Changes since $from:"
      jj log --reversed -r "$from..@" --no-graph -T 'change_id ++ "\n"' | while read -r change; do
          # Exclude trunk
          if [ "$change" = "$trunk" ]; then
              continue
          fi

          jj log -r "$change"
          jj diff --stat -r "$change"
          echo -e "\n"
      done
    '')

    (writeShellScriptBin "jj-workspace-exists" ''
      set -euo pipefail
      if [ "$#" -ne 1 ] || [ -z "$1" ]; then
        echo "Usage: jj-workspace-exists <workspace-name>" >&2
        exit 1
      fi

      name="$1"
      jj workspace list --ignore-working-copy -T 'name ++ "\n"' | grep -Fx -- "$name" > /dev/null
    '')

    (writeShellScriptBin "jj-workspace-add" ''
      set -euo pipefail
      if [ "$#" -ne 1 ] || [ -z "$1" ]; then
        echo "Usage: jj-workspace-add <workspace-name>" >&2
        exit 1
      fi

      name="$1"
      if jj-workspace-exists "$name"; then
        echo "Workspace '$name' already exists" >&2
        exit 1
      fi

      root=$(jj-workspace-path default)
      mkdir -p "$root/.workspaces"
      jj workspace add --colocate --name "$name" "$root/.workspaces/$name"
    '')

    (writeShellScriptBin "jj-workspace-delete" ''
      set -euo pipefail
      if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
        echo "Usage: jj-workspace-delete [workspace-name]" >&2
        exit 1
      fi

      if ! name=$(jj-workspace-select "$@"); then
        exit 1
      fi

      if [ "$name" = "default" ]; then
        echo "Refusing to delete the default workspace" >&2
        exit 1
      fi

      root=$(jj-workspace-path default)
      if ! ws_root=$(jj-workspace-path "$name"); then
        echo "Could not resolve the path of workspace '$name'" >&2
        exit 1
      fi
      if [ ! -d "$ws_root" ]; then
        echo "Workspace '$name' directory not found: $ws_root" >&2
        echo "Untrack it manually with: jj workspace forget $name" >&2
        exit 1
      fi

      jj workspace forget "$name"

      # Best-effort herdr cleanup if opened (the remove also closes the workspace).
      if wt_json=$(herdr worktree list --json 2>/dev/null); then
        wsid=$(printf '%s' "$wt_json" \
          | jq -r --arg path "$ws_root" '[.result.worktrees[] | select(.path == $path) | .open_workspace_id] | .[0] // empty' \
          2>/dev/null || true)
        if [ -n "$wsid" ] && [ "$wsid" != "null" ]; then
          herdr worktree remove --workspace "$wsid" --force >/dev/null 2>&1 || true
        fi
      fi

      if [ -d "$ws_root" ]; then
        rm -rf "$ws_root"
      fi

      # Prune any stale git worktrees
      git -C "$root" worktree prune >/dev/null 2>&1 || true
    '')

    (writeShellScriptBin "jj-workspace-path" ''
      set -euo pipefail

      if [ "$#" -ne 1 ] || [ -z "$1" ]; then
        echo "Usage: jj-workspace-path <workspace-name>" >&2
        exit 1
      fi

      name="$1"
      if root=$(jj workspace root --ignore-working-copy --name "$name" 2>/dev/null); then
        printf '%s\n' "$root"
        exit 0
      fi

      if [ "$name" != "default" ]; then
        echo "Workspace '$name' not found" >&2
        exit 1
      fi

      candidate_root=$(jj workspace root --ignore-working-copy)
      while [ "$(basename "$(dirname "$candidate_root")")" = ".workspaces" ]; do
        candidate_root=$(dirname "$(dirname "$candidate_root")")
      done

      if [ -d "$candidate_root/.jj/repo" ]; then
        printf '%s\n' "$candidate_root"
        exit 0
      fi

      echo "Workspace 'default' could not be resolved from legacy .workspaces layout" >&2
      exit 1
    '')

    (writeShellScriptBin "jj-workspace-select" ''
      set -euo pipefail

      if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
        echo "Usage: jj-workspace-select [workspace-name]" >&2
        exit 1
      fi

      if [ "$#" -eq 1 ]; then
        if ! jj-workspace-exists "$1"; then
          echo "Workspace '$1' not found" >&2
          exit 1
        fi

        printf '%s\n' "$1"
        exit 0
      fi

      if ! name=$(jj workspace list --ignore-working-copy -T 'name ++ "\n"' | fzf --prompt 'Workspace > ' --height 40% --layout reverse --border); then
        exit 1
      fi

      if [ -z "$name" ]; then
        exit 1
      fi

      printf '%s\n' "$name"
    '')

    (writeShellScriptBin "jj-workspace-tmux" ''
      set -euo pipefail

      if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ -z "$1" ]; }; then
        echo "Usage: jj-workspace-tmux [workspace-name]" >&2
        exit 1
      fi

      if [ -z "''${TMUX-}" ]; then
        echo "jjwt only works inside tmux" >&2
        exit 1
      fi

      # Creates if it doesn't exist
      if [ "$#" -eq 1 ] && [ -n "$1" ] && ! jj-workspace-exists "$1"; then
        jj-workspace-add "$1" || exit 1
        name="$1"
      else
        name=$(jj-workspace-select "$@")
      fi

      root=$(jj-workspace-path "$name")

      window_id=$(
        tmux list-windows -F '#{window_id}\t#{window_name}\t#{@jj_workspace_root}\t#{pane_current_path}' \
          | while IFS="$(printf '\t')" read -r id window_name workspace_root pane_path; do
              if [ "$window_name" = "$name" ] && { [ "$workspace_root" = "$root" ] || [ "$pane_path" = "$root" ]; }; then
                printf '%s\n' "$id"
                break
              fi
            done
      )

      if [ -n "$window_id" ]; then
        tmux select-window -t "$window_id"
      else
        window_id=$(tmux new-window -P -F '#{window_id}' -c "$root" -n "$name")
        tmux set-window-option -t "$window_id" @jj_workspace_root "$root" >/dev/null
      fi
    '')

    (writeShellScriptBin "jj-workspace-herdr" ''
      set -euo pipefail

      if ! herdr worktree list --json > /dev/null 2>&1; then
        echo "jjwh: cannot reach the herdr server; start herdr first" >&2
        exit 1
      fi

      # Creates if it doesn't exist
      if [ "$#" -eq 1 ] && [ -n "$1" ] && ! jj-workspace-exists "$1"; then
        jj-workspace-add "$1" || exit 1
        name="$1"
      else
        name=$(jj-workspace-select "$@")
      fi

      default=$(jj-workspace-path default)
      root=$(jj-workspace-path "$name")

      if ! out=$(herdr worktree open --cwd "$default" --path "$root" --label "$name" --focus 2>&1); then
        echo "jjwh: failed to open workspace '$name' in herdr:" >&2
        printf '%s\n' "$out" >&2
        exit 1
      fi
    '')
  ];

  programs.fish = {
    functions = {
      jj-select = ''
        jj root --ignore-working-copy >/dev/null 2>&1; or return 1
        jj log --no-graph -r "all()" -T 'change_id.shortest() ++ "\t" ++ author.timestamp().ago() ++ " " ++ description.first_line() ++ " "  ++ bookmarks.join("  ") ++ "\n"' --color always | fzf --ansi --height 40% --layout reverse --border --preview 'jj diff --stat -r {1}' | cut -f1
      '';

      jj-b-select = ''
        jj log --no-graph -r 'bookmarks()' -T 'coalesce(local_bookmarks) ++ "\n"' --color always | sed 's/ *\\*$//' | fzf --ansi | cut -f1
      '';

      jj-workspace-switch = ''
        set -l name (jj-workspace-select $argv)
        or return 1

        set -l root (jj-workspace-path "$name")
        or return 1

        cd "$root"
      '';

      jjws = ''
        jj-workspace-switch $argv
      '';

      jjwt = ''
        jj-workspace-tmux $argv
      '';

      jjwh = ''
        jj-workspace-herdr $argv
      '';
    };

    shellAbbrs = {
      jjt = "jj-proj-tug";
      jjg = "jj pull";
      jjp = "jj push";
      jjpr = {
        expansion = "gh pr create --head (jj-current-branch) --draft --body \"\" --title \"%\"";
        setCursor = true;
      };
      jjspr = {
        expansion = "gh pr create --base (jj-prev-branch) --head (jj-current-branch) --draft --body \"\" --title \"%\"";
        setCursor = true;
      };
      jjrt = "jj rebase-trunk";
      jjsi = "jj squash -t (jj-select) -i";
      jjsw = "jj squash-working";
      jjci = "jj commit -i";
      jjcm = {
        expansion = "jj commit -m \"%\"";
        setCursor = true;
      };
      jjcmi = {
        expansion = "jj commit -i -m \"%\"";
        setCursor = true;
      };

      jjwt = "jj-workspace-tmux";
      jjwh = "jj-workspace-herdr";
      jjwu = "jj workspace update-stale";
      jjwls = "jj workspace list";
      jjwa = "jj-workspace-add";
      jjwc = "jj-workspace-add";
      jjwd = "jj-workspace-delete";
      jjwrm = "jj-workspace-delete";
    };

    interactiveShellInit = ''
      # Bind Ctrl+G to select a jj revision
      bind -M insert \cg 'commandline -i (jj-select)'
    '';
  };
}
