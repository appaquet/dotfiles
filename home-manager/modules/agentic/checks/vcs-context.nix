{ pkgs, vcsContext }:

pkgs.runCommand "agentic-vcs-context-check"
  {
    nativeBuildInputs = [
      vcsContext
      pkgs.git
      pkgs.jujutsu
    ];
  }
  ''
    set -eu

    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME"

    assert_context() {
      expected="$1"
      mode="$2"
      directory="$3"
      actual=$(cd "$directory" && agentic-vcs-context "$mode")

      if [ "$actual" != "$expected" ]; then
        echo "Expected '$expected', got '$actual' in $directory" >&2
        exit 1
      fi
    }

    jj_repo="$TMPDIR/jj default context"
    jj git init --no-colocate "$jj_repo" >/dev/null
    (
      cd "$jj_repo"
      jj config set --repo user.name Test >/dev/null
      jj config set --repo user.email test@example.com >/dev/null
      jj config set --repo 'revset-aliases."trunk()"' stable >/dev/null
      jj config set --repo 'revset-aliases."closest_bookmark(to)"' 'heads(::to & bookmarks())' >/dev/null
      jj bookmark create stable -r @ >/dev/null
    )

    assert_context "JJ workspace: default" jj "$jj_repo"

    (
      cd "$jj_repo"
      jj new stable >/dev/null
      jj bookmark create feature-context -r @ >/dev/null
    )
    assert_context "${
      builtins.concatStringsSep "\n" [
        "Branch: feature-context"
        "JJ workspace: default"
      ]
    }" jj "$jj_repo"

    jj_workspace="$TMPDIR/jj named context"
    (
      cd "$jj_repo"
      jj workspace add --name task-context -r 'root()' "$jj_workspace" >/dev/null
    )
    assert_context "JJ workspace: task-context" jj "$jj_workspace"

    git_repo="$TMPDIR/git main context"
    git init --initial-branch=stable "$git_repo" >/dev/null
    (
      cd "$git_repo"
      git config user.name Test
      git config user.email test@example.com
      touch tracked
      git add tracked
      git commit -m initial >/dev/null
      git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/stable
    )

    assert_context "Git worktree: git main context" git "$git_repo"

    (
      cd "$git_repo"
      git switch -c feature-context >/dev/null
    )
    assert_context "${
      builtins.concatStringsSep "\n" [
        "Branch: feature-context"
        "Git worktree: git main context"
      ]
    }" git "$git_repo"

    git_worktree="$TMPDIR/git-context-worktree"
    (
      cd "$git_repo"
      git switch stable >/dev/null
      git worktree add --detach "$git_worktree" stable >/dev/null
    )
    assert_context "Git worktree: git-context-worktree" git "$git_worktree"

    if agentic-vcs-context invalid >invalid.out 2>invalid.err; then
      echo "Invalid VCS mode unexpectedly succeeded" >&2
      exit 1
    fi
    grep -F "Expected one of: jj, git" invalid.err

    touch "$out"
  ''
