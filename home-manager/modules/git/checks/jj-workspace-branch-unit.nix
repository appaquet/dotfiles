{
  pkgs,
  branchScript,
  unitTest,
}:

# Behavioral check for the jj-workspace-branch command. The suite drives throwaway
# jujutsu repositories and asserts bookmark creation at the workspace's working
# copy, idempotent re-runs, and default-workspace rejection against the packaged
# binary. Its files are referenced through the flake source tree, which only
# carries snapshotted files.
pkgs.runCommand "jj-workspace-branch-unit-check"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.jujutsu
    ];
  }
  ''
    JJ_WORKSPACE_BRANCH_BIN=${pkgs.writeShellScriptBin "jj-workspace-branch" (builtins.readFile branchScript)}/bin/jj-workspace-branch \
      bash ${unitTest}

    touch "$out"
  ''
