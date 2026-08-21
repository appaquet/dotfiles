{
  nixantic.sources.version-control.blocks."current-branch" =
    { scope }:
    {
      content = scope.forHarness {
        pi = ''
          Run `${
            scope.forSetting "versionControl.mode" {
              jj = "jj-current-branch";
              git = "git branch --show-current";
            }
          }` with the shell tool, then use its stdout as current branch / change context.
        '';
        default = ''
          Current branch / change context: `${
            scope.forSetting "versionControl.mode" {
              jj = "!`jj-current-branch`";
              git = "!`git branch --show-current`";
            }
          }`
        '';
      };
    };
}
