{ pkgs }:

# Regression tests for the shared feedback component. The suite imports the module
# directly, so it needs neither a browser nor the packaged skill tree.
pkgs.runCommand "show-me-kit-check"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    set -eu
    mkdir suite
    cp ${../tools/show-me-feedback.js} suite/show-me-feedback.js
    cp ${../tools/show-me-feedback.test.mjs} suite/show-me-feedback.test.mjs
    cp ${../tools/show-me-serve.ts} suite/show-me-serve.ts
    cp ${../tools/show-me-serve.test.ts} suite/show-me-serve.test.ts
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
