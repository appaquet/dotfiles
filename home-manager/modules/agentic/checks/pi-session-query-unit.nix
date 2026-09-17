{ pkgs }:

# Unit tests for the pi-session-query command. The suite imports the script directly,
# so it neither needs the packaged wrapper nor a session store. Its file is referenced
# through the flake source tree, which only carries git-tracked files.
pkgs.runCommand "pi-session-query-unit-check"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.gnugrep
    ];
  }
  ''
    set -eu

    if ! python3 ${../tools}/pi-session-query.test.py >unit.out 2>&1; then
      cat unit.out >&2
      exit 1
    fi

    if ! grep -E "Ran [1-9][0-9]* tests" unit.out >/dev/null; then
      echo "The unit suite reported no tests" >&2
      cat unit.out >&2
      exit 1
    fi

    if ! grep -E "^(OK)$" unit.out >/dev/null; then
      echo "The unit suite did not pass" >&2
      cat unit.out >&2
      exit 1
    fi

    touch "$out"
  ''
