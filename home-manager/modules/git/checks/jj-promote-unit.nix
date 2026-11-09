{
  pkgs,
  jjUtils,
  unitTest,
}:

# Behavioral check for the jj-promote command. The suite drives throwaway jujutsu
# repositories and asserts description rewrites, skip rules, dry-run purity, and error
# handling against the command built into the jj-utils package.
pkgs.runCommand "jj-promote-unit-check"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jujutsu
      jjUtils
    ];
  }
  ''
    JJ_PROMOTE_BIN=${jjUtils}/bin/jj-promote \
      bash ${unitTest}

    touch "$out"
  ''
