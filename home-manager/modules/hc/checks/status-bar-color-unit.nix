{ pkgs }:

# Regression tests for the status bar's usage tier scale: the remaining percentage at which a Claude window warns and
# the one at which it goes critical, plus the readings that must never alarm. The suite imports the module directly, so
# it needs neither the app nor the linked mod folder.
pkgs.runCommand "status-bar-color-unit-check"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    set -eu
    mkdir suite
    cp ${../app/ap/mods/status-bar/color.js} suite/color.js
    cp ${../app/ap/mods/status-bar/color.test.js} suite/color.test.js
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
