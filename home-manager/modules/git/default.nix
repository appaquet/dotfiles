{ pkgs, ... }:
{
  home.packages = with pkgs; [
    git
  ];

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

      github.user = "appaquet";

      push.autoSetupRemote = true;

      rerere.enabled = true;

      core.editor = "nvim";
      core.fileMode = false;
      core.ignorecase = false;

      branch.sort = "-committerdate";

      init.defaultBranch = "main";

      diff.algorithm = "histogram";

      core.excludeFiles = "~/.gitignore";

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
