{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    git
    gh
    lazygit

    # allows adding filers to prior commits automatically based on directories
    # see https://github.com/tummychow/git-absorb
    git-absorb

    fzf
  ];

  humanfirst.git.enable = true; # gcmp, gb, gh-pr-select, git-tag-select

  programs.fish = {
    shellAbbrs = {
      gs = "git status";
      gl = "git log";
      gls = "git log --stat";
      glm = "git log --merges --first-parent";
      gd = "git diff";
      gds = "git diff --staged";
      gp = "git pull";
      gck = "git checkout";
      gckbp = "git checkout (git-prev-branch)";
      gckbn = "git checkout (git-next-branch)";
      gcm = {
        expansion = "git commit -m \"%\"";
        setCursor = true;
      };
      gcp = "git reset --soft HEAD~1"; # git commit pop
      gchm = "git commit -m (git log -1 --pretty=format:%s)";
      gpom = "git pull origin master";
      gpr = "git pull --rebase --autostash";
      gpf = "git push --force-with-lease";
      gca = "git commit --amend";
      gr = "git rev-parse --short=7 @";
      grc = "GIT_EDITOR=true git rebase --continue";
      gri = "git rebase -i --committer-date-is-author-date --autostash";
      grs = "git restore --staged";
      grsw = "git restore --staged --worktree";
      grws = "git restore --staged --worktree";
      ghpr = "gh pr create --draft --body \"\" --title";
      ghck = "git checkout (gh-pr-select)";
      gham = {
        expansion = "for pr in %; gh pr review --approve $pr; gh pr merge --merge --auto $pr; end";
        setCursor = true;
      };
      gts = "git checkout (git-tag-select)";
      gau = "git add -u";
      ga = "git add";
      gad = "git add .";
      gmr = "git maintenance run";

      gbc = "git-current-branch";
      gbp = "git-prev-branch";
      gbn = "git-next-branch";
      gbs = "git-stacked-branches";
    };

    functions = {
      git-current-branch = ''
        git symbolic-ref --short HEAD
      '';

      # if this fails, run `git remote set-head origin -a`
      git-main-branch = ''
        git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
      '';

      git-stacked-branches = ''
        git log --pretty='%D' origin/(git-main-branch)... |
              grep -oE '\b[^, ]+\b' |
              grep -vE '^(HEAD|origin/)' |
              sort | uniq
      '';

      git-prev-branch = ''
        git-stacked-branches | head -n 1
      '';

      git-next-branch = ''
        set current_branch (git symbolic-ref --short HEAD)
        for branch in (git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/)
            if test $branch != $current_branch
                git merge-base --is-ancestor $current_branch $branch
                echo $branch
                break
            end
        end
      '';
    };
  };

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
