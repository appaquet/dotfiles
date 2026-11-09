{ pkgs, ... }:
let
  jjUtils = import ./jj-utils.nix { inherit pkgs; };
in
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
        "unreviewed()" = "description(glob:'unreviewed:*')";
        "agent()" = "description(glob:'unreviewed:*') | description(glob:'private: agent:*')";
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
    jjUtils
  ];

  programs.fish = {
    functions = {
      jj-select = ''
        jj root --ignore-working-copy >/dev/null 2>&1; or return 1
        jj log --no-graph -r "all()" -T 'change_id.shortest() ++ "\t" ++ author.timestamp().ago() ++ " " ++ description.first_line() ++ " "  ++ bookmarks.join("  ") ++ "\n"' --color always | fzf --ansi --height 40% --layout reverse --border --preview 'jj diff --stat -r {1}' | cut -f1
      '';

      jj-b-select = ''
        jj log --no-graph -r 'bookmarks()' -T 'local_bookmarks.map(|b| b.name()).join(",") ++ "\n"' --color always | fzf --ansi | cut -f1
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
      jjpm = "jj-promote";
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
      jjwb = "jj-workspace-branch";
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
