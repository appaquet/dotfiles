{ unstablePkgs, ... }:
{
  programs.jujutsu = {
    enable = true;

    package = unstablePkgs.jujutsu; # stable cannot be installed

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
        push-new-bookmarks = true; # allow pushing new boomarks without explicit flag
      };
      revset-aliases = {
        "closest_bookmark(to)" = "heads(::to & bookmarks())";
        "recent()" = "committer_date(after:\"1 months ago\")";
      };
      aliases = {
        "tug" = [
          "bookmark"
          "move"
          "--from"
          "closest_bookmark(@-)"
          "--to"
          "@-"
        ];
        "pull" = [
          "git"
          "fetch"
        ];
        "push" = [
          "git"
          "push"
        ];
        "rebase-trunk" = [
          "rebase"
          "-s"
          "all:roots(trunk()..@)" # root of any branches that leads us to trunk allowing support for multi-parents
          "-d"
          "trunk()" # rebase on trunk
        ];
      };
    };
  };

  programs.fish = {
    shellAbbrs = {
      "jjpr" = {
        expansion = "gh pr create --head (jj-current-branch) --draft --body \"\" --title \"%\"";
        setCursor = true;
      };
    };

    functions = {
      jj-current-branch = "jj log --no-graph -r \"closest_bookmark(@)\" -T \"coalesce(local_bookmarks)\"";

      jj-stacked-branches = "jj log --no-graph -r 'trunk()..@ & bookmarks()' -T 'coalesce(local_bookmarks) ++ \"\n\"'";

      jj-stacked-stats = ''
        for change in (jj log --reversed -r 'trunk()..@' --no-graph -T 'change_id ++ "\n"')
             jj log -r $change
             jj diff --stat -r $change
             echo -e "\n"
        end
      '';
    };
  };
}
