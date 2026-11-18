{
  pkgs,
  jjUtils,
  unitTest,
}:

# Behavioral check for workspace bookmark target selection and updates.
pkgs.runCommand "jj-workspace-branch-unit-check"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jujutsu
      jjUtils
    ];
  }
  ''
    JJ_WORKSPACE_BRANCH_BIN=${jjUtils}/bin/jj-workspace-branch \
      bash ${unitTest}

    touch "$out"
  ''
