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
        "claude()" = "description(glob:'private: claude:*')";
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
        ];

        # Rebase current branch onto trunk with support for multi-parents
        "rebase-trunk" = [
          "rebase"
          "-s"
          "roots(trunk()..@)" # root of any branches that leads us to trunk allowing support for multi-parents
          "-d"
          "trunk()" # rebase on trunk
        ];

        # Squash consecutive working changes (claude's, empty, undescribed) into @
        "squash-working" = [
          "squash"
          "--from"
          "(trunk()..@) & latest((trunk()..@) & ~(empty() | claude() | description(exact:'')))..(@- & (empty() | claude() | description(exact:'')))"
          "--to"
          "@"
        ];
      };
    };
  };

  home.packages = with pkgs; [
    jjui
    (writeShellScriptBin "jj-proj-tug" ''
      if [ "$(jj log --no-graph -r '@' -T 'empty')" = "false" ]; then
        jj new
      fi
      PROJ=$(jj log --no-graph -r 'latest(proj())' -T 'change_id.shortest()')
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
  ];

  programs.fish = {
    functions = {
      jj-select = ''
        jj log --no-graph -T 'change_id.shortest() ++ "\t" ++ author.timestamp().ago() ++ " " ++ description.first_line() ++ " "  ++ bookmarks.join("  ") ++ "\n"' --color always | fzf --ansi --height 40% --layout reverse --border --preview 'jj diff --stat -r {1}' | cut -f1
      '';

      jj-b-select = ''
        jj log --no-graph -r 'bookmarks()' -T 'coalesce(local_bookmarks) ++ "\n"' --color always | sed 's/ *\\*$//' | fzf --ansi | cut -f1
      '';
    };

    shellAbbrs = {
      jjt = "jj-proj-tug";
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
    };

    interactiveShellInit = ''
      # Bind Ctrl+J to select a jj revision
      bind -M insert \cj 'commandline -i (jj-select)'
    '';
  };
}
