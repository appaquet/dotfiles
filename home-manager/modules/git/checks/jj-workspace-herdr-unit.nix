{
  pkgs,
  jjUtils,
  unitTest,
}:

# Behavioral check for the Herdr side of the jj workspace utilities (open and delete). Both
# commands talk to herdr-app and herdr-core, which need a running window and core, so the
# suite stubs them on PATH and asserts the exact commands and their order.
pkgs.runCommand "jj-workspace-herdr-unit-check"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jq
      pkgs.jujutsu
      jjUtils
    ];
  }
  ''
    JJ_UTILS_BIN=${jjUtils}/bin \
      bash ${unitTest}

    touch "$out"
  ''
