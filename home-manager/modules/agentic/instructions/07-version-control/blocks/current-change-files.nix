{
  nixantic.sources.version-control.blocks."current-change-files" =
    { scope }:
    {
      content = scope.forHarness {
        pi = ''
          Run `${
            scope.forSetting "versionControl.mode" {
              jj = "jj-diff-branch --stat";
              git = "git diff --stat $(git merge-base HEAD origin/HEAD)..HEAD";
            }
          }` with the shell tool, then use its stdout as changed files in the current branch.
        '';
        default = ''
          Changed files in current branch:
          ```
          !`${
            scope.forSetting "versionControl.mode" {
              jj = "jj-diff-branch --stat";
              git = "git diff --stat $(git merge-base HEAD origin/HEAD)..HEAD";
            }
          }`
          ```
        '';
      };
    };
}
