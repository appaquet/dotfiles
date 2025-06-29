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
        push-new-bookmarks = true; # allow pushing new boomarks without explicit flag
      };
      revset-aliases = {
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
      };
    };
  };

  home.packages = with pkgs; [
    jjui
  ];

  programs.fish = {
    shellAbbrs = {
    };

    functions = {
      jj-stacked-stats = ''
        if test -n "$argv[1]"
            set from $argv[1]
        else
            set from "trunk()"
        end
        set trunk (jj-main-branch)
        echo "Changes since $from:"
        for change in (jj log --reversed -r "$from..@" --no-graph -T 'change_id ++ "\n"')
             # Exclude trunk
              if test "$change" = "$trunk"
                  continue
              end

             jj log -r $change
             jj diff --stat -r $change
             echo -e "\n"
        end
      '';
    };
  };
}
