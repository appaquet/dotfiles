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
      name="$1"
      jj workspace list --ignore-working-copy -T 'name ++ "\n"' | grep -Fxq "$name"
    '')

    (writeShellScriptBin "jj-workspace-add" ''
      set -euo pipefail
      name="$1"
      if [ -z "$name" ]; then
        echo "Usage: jj-workspace-add <workspace-name>" >&2
        exit 1
      fi
      if jj-workspace-exists "$name"; then
        echo "Workspace '$name' already exists" >&2
        exit 1
      fi
      root=$(jj workspace root)
      mkdir -p "$root/.workspaces"
      jj workspace add --name "$name" "$root/.workspaces/$name"
    '')

    (writeShellScriptBin "jj-workspace-delete" ''
      set -euo pipefail
      if [ "$#" -gt 1 ]; then
        echo "Usage: jj-workspace-delete [workspace-name]" >&2
        exit 1
      fi

      if ! name=$(jj-workspace-select "$@"); then
        exit 1
      fi

      root=$(jj workspace root)
      jj workspace forget "$name"
      if [ -d "$root/.workspaces/$name" ]; then
        rm -rf "$root/.workspaces/$name"
      fi
    '')

    (writeShellScriptBin "jj-workspace-path" ''
      set -euo pipefail

      name="''${1-}"
      if [ -z "$name" ]; then
        echo "Usage: jj-workspace-path <workspace-name>" >&2
        exit 1
      fi

      if root=$(jj workspace root --ignore-working-copy --name "$name" 2>/dev/null); then
        printf '%s\n' "$root"
        exit 0
      fi

      if [ "$name" != "default" ]; then
        echo "Workspace '$name' not found" >&2
        exit 1
      fi

      current_root=$(jj workspace root --ignore-working-copy)
      parent_dir=$(dirname "$current_root")

      if [ "$(basename "$parent_dir")" != ".workspaces" ]; then
        if [ -d "$current_root/.jj" ]; then
          printf '%s\n' "$current_root"
          exit 0
        fi

        echo "Workspace 'default' has no recorded path, and legacy fallback only works from the repo root or a workspace under .workspaces/" >&2
        exit 1
      fi

      candidate_root=$(dirname "$parent_dir")

      if [ -d "$candidate_root/.jj" ]; then
        printf '%s\n' "$candidate_root"
        exit 0
      fi

      echo "Workspace 'default' could not be resolved from legacy .workspaces layout" >&2
      exit 1
    '')

    (writeShellScriptBin "jj-workspace-select" ''
      set -euo pipefail

      if [ "$#" -gt 1 ]; then
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

      if [ -z "''${TMUX-}" ]; then
        echo "jjwt only works inside tmux" >&2
        exit 1
      fi

      name=$(jj-workspace-select "$@")
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
