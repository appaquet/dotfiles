{
  pkgs,
  jjUtils,
  unitTest,
}:

# Behavioral check for the jj workspace utilities (name, exists, select, path, add). Every
# one of these commands hands a workspace name to another command, so the suite holds a
# plain name and a name jj renders quoted, and asserts each command resolves both.
pkgs.runCommand "jj-workspace-utils-unit-check"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jujutsu
      jjUtils
    ];
  }
  ''
    JJ_UTILS_BIN=${jjUtils}/bin \
      bash ${unitTest}

    touch "$out"
  ''
