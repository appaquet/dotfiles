{ pkgs, vcsContext }:

pkgs.runCommand "agentic-vcs-context-check"
  {
    nativeBuildInputs = [
      vcsContext
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
      directory="$2"
      actual=$(cd "$directory" && agentic-vcs-context)

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

    assert_context "JJ workspace: default" "$jj_repo"

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
    }" "$jj_repo"

    jj_workspace="$TMPDIR/jj named context"
    (
      cd "$jj_repo"
      jj workspace add --name task-context -r 'root()' "$jj_workspace" >/dev/null
    )
    assert_context "JJ workspace: task-context" "$jj_workspace"

    touch "$out"
  ''
