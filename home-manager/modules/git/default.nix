{ pkgs, config, ... }:
{
  imports = [
    ./jujutsu.nix
  ];

  home.packages = with pkgs; [
    git
    gh
    lazygit

    # allows adding files to prior commits automatically based on directories
    # see https://github.com/tummychow/git-absorb
    git-absorb

    fzf
  ];

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
      git-current-branch = # fish
        ''
          git symbolic-ref --short HEAD
        '';

      # if this fails, run `git remote set-head origin -a`
      git-main-branch = # fish
        ''
          git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@' | tr -d '\n'
        '';

      git-stacked-branches = # fish
        ''
          git log --pretty='%D' origin/(git-main-branch)... |
                grep -oE '\b[^, ]+\b' |
                grep -vE '^(HEAD|origin/)' |
                sort | uniq
        '';

      git-prev-branch = # fish
        ''
          git-stacked-branches | head -n 2 | tail -n 1
        '';

      git-next-branch = # fish
        ''
          set current_branch (git symbolic-ref --short HEAD)
          for branch in (git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/)
              if test $branch != $current_branch
                  git merge-base --is-ancestor $current_branch $branch
                  echo $branch
                  break
              end
          end
        '';

      gb = # fish
        ''
          set COMMAND 'git for-each-ref --sort=-committerdate refs/heads/ --format="%(color: red)%(committerdate:short)%(color: 244)|%(color: cyan)%(refname:short)%(color: 244)|%(color: green)%(subject)" --color=always | column -ts"|"'
          FZF_DEFAULT_COMMAND=$COMMAND fzf \
            --ansi \
            --header "enter to checkout, ctrl-d to delete" \
            --bind "ctrl-d:execute(echo {+} | awk '{print \$2}' | xargs git branch -D)+reload:$COMMAND" \
            | awk '{print $2}' | xargs git checkout
        '';

      gcpm = # fish
        ''
          MSG=(git log --first-parent --pretty=format:%s | head -n 100 | uniq | head -n 10 | fzf) git commit -m "$MSG"
        '';

      gh-pr-select = # fish
        ''
          set COMMAND 'gh pr list --json number,title,author,headRefName,updatedAt \
          --template "{{tablerow \"Ref\" \"PR\" \"Title\" \"Author\" \"Date\"}}{{range .}}{{tablerow (.headRefName | color \"blue\") (printf \"#%v\" .number | color \"yellow\") (.title | color \"green\") (.author.name | color \"cyan\") (timeago .updatedAt)}}{{end}}"'
          GH_FORCE_TTY=100% FZF_DEFAULT_COMMAND=$COMMAND fzf \
                    --ansi \
                    --header-lines=1 \
                    --no-multi \
                    --prompt 'Search Open PRs > ' \
                    | awk '{print $1}'
        '';

      git-tag-select = # fish
        ''
          set COMMAND "git tag -l --sort=-version:refname --color=always --format='%(color:red)%(refname:short) %(color: cyan) - %(color: green)%(creatordate:short)'"
          FZF_DEFAULT_COMMAND=$COMMAND fzf \
                  --ansi \
                  --prompt 'Search tags > ' \
                  | awk '{print $1}'
        '';
    };
  };

  programs.git = {
    enable = true;
    signing.format = null;

    settings = {
      user = {
        name = "Andre-Philippe Paquet";
        email = "appaquet@gmail.com";
      };
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

      core.excludesFile = "${config.home.homeDirectory}/.gitignore"; # global git ignore

      # Early corruption detection
      transfer.fsckObjects = true;
      fetch.fsckObjects = true;
      receive.fsckObjects = true;

      include = {
        path = "${./delta-theme.gitconfig}";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # N to switch files
      syntax-theme = "Nord";
      side-by-side = false;
      features = "chameleon-mod";
    };
  };

  home.file.".gitignore".source = ./global-gitignore;
}
