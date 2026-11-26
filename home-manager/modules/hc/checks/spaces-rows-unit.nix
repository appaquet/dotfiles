{ pkgs }:

# Unit tests for worktree grouping and folding, the sidebar's saved machine order, sidebar-order navigation, and space/repo naming.
# The suite imports the helpers without needing the app or the linked mod folder.
pkgs.runCommand "spaces-rows-unit-check"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    set -eu
    mkdir suite
    cp ${../app/ap/mods/spaces-status/rows.js} suite/rows.js
    cp ${../app/ap/mods/spaces-status/rows.test.js} suite/rows.test.js
    cp ${../app/ap/mods/spaces-status/machine-order.js} suite/machine-order.js
    cp ${../app/ap/mods/spaces-status/machine-order.test.js} suite/machine-order.test.js
    cp ${../app/ap/mods/spaces-status/nav.js} suite/nav.js
    cp ${../app/ap/mods/spaces-status/nav.test.js} suite/nav.test.js
    cp ${../app/ap/mods/spaces-status/names.js} suite/names.js
    cp ${../app/ap/mods/spaces-status/names.test.js} suite/names.test.js
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
