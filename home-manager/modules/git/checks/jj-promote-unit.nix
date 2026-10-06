{
  pkgs,
  promoteScript,
  unitTest,
}:

# Behavioral check for the jj-promote command. The suite drives throwaway jujutsu
# repositories and asserts description rewrites, skip rules, dry-run purity, and error
# handling against the packaged binary. Its files are referenced through the flake source
# tree, which only carries snapshotted files.
pkgs.runCommand "jj-promote-unit-check"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jujutsu
    ];
  }
  ''
    set -eu

    JJ_PROMOTE_BIN=${pkgs.writeShellScriptBin "jj-promote" (builtins.readFile promoteScript)}/bin/jj-promote \
      bash ${unitTest}

    touch "$out"
  ''
