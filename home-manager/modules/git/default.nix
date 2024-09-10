{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    git
    gh

    # allows adding filers to prior commits automatically based on directories
    # see https://github.com/tummychow/git-absorb
    git-absorb

    fzf
  ];

  programs.fish.functions.gh-pr-select = ''
    set COMMAND 'gh pr list --json number,title,author,headRefName,updatedAt \
    --template "{{tablerow \"Ref\" \"PR\" \"Title\" \"Author\" \"Date\"}}{{range .}}{{tablerow (.headRefName | color \"blue\") (printf \"#%v\" .number | color \"yellow\") (.title | color \"green\") (.author.name | color \"cyan\") (timeago .updatedAt)}}{{end}}"'
    GH_FORCE_TTY=100% FZF_DEFAULT_COMMAND=$COMMAND fzf \
              --ansi \
              --header-lines=1 \
              --no-multi \
              --prompt 'Search Open PRs > ' \
              | awk '{print $1}'
  '';

  programs.git = {
    enable = true;
    userName = "Andre-Philippe Paquet";
    userEmail = "appaquet@gmail.com";

    delta = {
      enable = true;
      options = {
        navigate = true; # N to switch files
        syntax-theme = "Nord";
        side-by-side = false;
        features = "chameleon-mod";
      };
    };

    extraConfig = {
      # Popular options here: https://jvns.ca/blog/2024/02/16/popular-git-config-options/
      # For some more: https://blog.gitbutler.com/git-tips-and-tricks/
      # For all options: https://git-scm.com/docs/git-config

      github.user = "appaquet";

      push.autoSetupRemote = true; # auto set upstream
      push.useForceIfIncludes = true; # only allow push if the remote ref is also locally (preventing accidental force push)

      rerere.enabled = true; # save merge conflict resolutions

      # better stacked branches support
      # see https://andrewlock.net/working-with-stacked-branches-in-git-is-easier-with-update-refs/
      rebase.updateRefs = true;

      core.editor = "nvim";
      core.fileMode = false;
      core.ignorecase = false;

      branch.sort = "-committerdate";

      init.defaultBranch = "main";

      diff.algorithm = "histogram"; # better diffing algorithm

      core.excludeFiles = "${config.home.homeDirectory}/.gitignore"; # global git ignore

      # Early corruption detection
      transfer.fsckobjects = true;
      fetch.fsckobjects = true;
      receive.fsckObjects = true;

      include = {
        path = "${./delta-theme.gitconfig}";
      };
    };
  };

  home.file.".gitignore".source = ./global-gitignore;
}
