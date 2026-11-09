{
  pkgs,
  jjUtils,
  unitTest,
}:

# Behavioral check for the jj-workspace-branch command. The suite drives throwaway
# jujutsu repositories and asserts bookmark creation at the workspace's working copy,
# idempotent re-runs, re-pointing, and default-workspace rejection against the command
# built into the jj-utils package, so the suite always exercises the source the user runs.
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
