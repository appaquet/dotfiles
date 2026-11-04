{ pkgs, projDocs }:

pkgs.runCommand "agentic-proj-docs-check"
  {
    nativeBuildInputs = [
      projDocs
      pkgs.git
      pkgs.jujutsu
    ];
  }
  ''
    set -eu

    # Resolved paths keep expectations stable where TMPDIR is a symlink
    TMPDIR=$(readlink -f "$TMPDIR")
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME"

    assert_docs_root() {
      expected="$1"
      directory="$2"
      output=$(cd "$directory" && agentic-proj-docs)
      actual=''${output%%$'\n'*}

      if [ "$actual" != "$expected" ]; then
        echo "Expected '$expected', got '$actual' in $directory" >&2
        exit 1
      fi
    }

    # Configured in the main clone, read from a colocated workspace with ~ expansion
    main="$TMPDIR/main"
    workspace="$TMPDIR/workspace"
    mkdir -p "$HOME/brain/docs/features"
    jj git init --colocate "$main" >/dev/null 2>&1
    git -C "$main" config agentic.docsRoot '~/brain/docs/features'
    (cd "$main" && jj workspace add --colocate --name ws "$workspace" >/dev/null 2>&1)
    mkdir -p "$workspace/sub"
    assert_docs_root "Docs root: $HOME/brain/docs/features (from git config agentic.docsRoot)" "$workspace"
    assert_docs_root "Docs root: $HOME/brain/docs/features (from git config agentic.docsRoot)" "$workspace/sub"

    # Configured directory missing: reported, no fallback to docs/features
    mkdir -p "$main/docs/features"
    git -C "$main" config agentic.docsRoot "$TMPDIR/missing"
    assert_docs_root "Docs root: missing, $TMPDIR/missing from git config agentic.docsRoot does not exist" "$main"

    # Unset: docs/features at the repository root, also from a subdirectory
    git -C "$main" config --unset agentic.docsRoot
    mkdir -p "$main/sub"
    assert_docs_root "Docs root: $main/docs/features (default docs/features)" "$main/sub"

    # Unset and no docs/features
    assert_docs_root "Docs root: none, git config agentic.docsRoot unset and no $workspace/docs/features" "$workspace"

    # Outside any repository
    mkdir -p "$TMPDIR/plain"
    assert_docs_root "Docs root: none, git config agentic.docsRoot unset and no $TMPDIR/plain/docs/features" "$TMPDIR/plain"

    # Full output with a committed project link
    mkdir -p "$main/docs/features/2026/01/01-demo"
    touch "$main/docs/features/2026/01/01-demo/00-demo.md" "$main/docs/features/2026/01/01-demo/01-phase.md"
    ln -s "$main/docs/features/2026/01/01-demo" "$main/proj"
    expected="Docs root: $main/docs/features (default docs/features)
    Project link (committed): $main/proj
    Project folder: $main/docs/features/2026/01/01-demo
    Project files:
    * 00-demo.md
    * 01-phase.md"
    actual=$(cd "$main" && agentic-proj-docs)
    if [ "$actual" != "$expected" ]; then
      printf 'Expected:\n%s\nGot:\n%s\n' "$expected" "$actual" >&2
      exit 1
    fi

    touch "$out"
  ''
