{ pkgs, ... }:
{
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # Lots in humanfirst-dots as well
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
      };

      revset-aliases = {
        "proj()" = "description(glob:'private: proj*')";
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
  ];

  programs.fish = {
    shellAbbrs = {
      jjt = "jj-proj-tug";
    };
  };
}
