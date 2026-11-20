{ pkgs }:

# Regression tests for the status bar's clock spelling: the padded 24-hour time the bar shows and the tooltip's reset
# wording (same day, another day, under an hour, already passed). The suite imports the module directly, so it needs
# neither the app nor the linked mod folder, and its instants are built from local wall-clock fields, which keeps the
# expectations timezone-free.
pkgs.runCommand "status-bar-clock-unit-check"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    set -eu
    mkdir suite
    cp ${../app/ap/mods/status-bar/clock.js} suite/clock.js
    cp ${../app/ap/mods/status-bar/clock.test.js} suite/clock.test.js
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
