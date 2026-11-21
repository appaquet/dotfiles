{ pkgs }:

# Unit tests for the spaces list's row grouping: worktree rows nested under their repo's first main
# checkout, tree markers, kids counts, the parents map the goto picker reads, and the fold's hidden
# marking. The suite imports the helpers directly, so it needs neither the app nor the linked mod folder.
pkgs.runCommand "spaces-rows-unit-check"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    set -eu
    mkdir suite
    cp ${../app/ap/mods/spaces-status/rows.js} suite/rows.js
    cp ${../app/ap/mods/spaces-status/rows.test.js} suite/rows.test.js
    cd suite
    if ! HOME=$TMPDIR bun test >unit.out 2>&1; then
      cat unit.out >&2
      exit 1
    fi

    if ! grep -E "^[[:space:]]+[1-9][0-9]* pass$" unit.out >/dev/null; then
      echo "The suite reported no passing tests" >&2
      cat unit.out >&2
      exit 1
    fi

    if ! grep -E "^[[:space:]]+0 fail$" unit.out >/dev/null; then
      echo "The suite reported failures" >&2
      cat unit.out >&2
      exit 1
    fi

    touch "$out"
  ''
