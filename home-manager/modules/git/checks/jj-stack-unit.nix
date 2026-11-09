{
  pkgs,
  jjUtils,
  unitTest,
}:

# Behavioral check for the jj stack commands (stacked-branches, prev-branch, main-branch,
# diff-branch, stacked-stats). Covers the two properties a one-bookmark repo cannot show:
# a stack deep enough for a reader to close the pipe early, and bookmark names printed
# without the marker jj renders for a bookmark that diverges from its remote.
pkgs.runCommand "jj-stack-unit-check"
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
