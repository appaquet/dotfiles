{ pkgs, piNode }:

# Hermetic run of the Pi plugin and library suites. They import Pi's own bundled
# packages, which the node-based Pi variant exposes through NODE_PATH.
pkgs.runCommand "pi-plugins-unit-check"
  {
    nativeBuildInputs = [
      pkgs.bun
    ];
  }
  ''
    set -eu

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export NODE_PATH=${piNode}/lib/node_modules/@earendil-works/pi-coding-agent/node_modules

    # The suites run from a writable copy because the store path is read-only.
    cp -r ${../.} pi-module
    cd pi-module

    bun test --isolate plugins/*.test.ts lib/*.test.ts

    touch "$out"
  ''
