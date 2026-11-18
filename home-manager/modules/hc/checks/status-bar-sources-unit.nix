{ pkgs }:

# Regression tests for the multi-machine usage sources: parsing a machine's separator dump, extracting windows and
# merging sources. The suite imports sources.js, which has no `herdr` import, so it needs neither the app nor the
# mod's linked folder.
pkgs.runCommand "status-bar-sources-unit-check"
  {
    nativeBuildInputs = [
      pkgs.bun
      pkgs.findutils # one test runs the real command, which finds the payloads
    ];
  }
  ''
    set -eu
    mkdir suite
    cp ${../app/ap/mods/status-bar/sources.js} suite/sources.js
    cp ${../app/ap/mods/status-bar/sources.test.js} suite/sources.test.js
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
