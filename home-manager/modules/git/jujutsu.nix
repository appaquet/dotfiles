{ unstablePkgs, ... }:
{
  # TODO: Better pager (same as git)

  programs.jujutsu = {
    enable = true;

    package = unstablePkgs.jujutsu; # stable cannot be installed

    # See https://github.com/jj-vcs/jj/blob/main/docs/config.md
    # Some goodies from https://zerowidth.com/2025/jj-tips-and-tricks/#bookmarks-and-branches
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
    # TODO: should they be aliases instead?
    functions = {
      "jj-current-branch" =
        "jj log --no-graph -r \"closest_bookmark(@)\" -T \"coalesce(local_bookmarks)\"";
      "jj-stacked-branches" =
        "jj log --no-graph -r 'trunk()..@ & bookmarks()' -T 'coalesce(local_bookmarks) ++ \"\n\"'";
    };
  };
}
