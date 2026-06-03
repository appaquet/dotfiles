{
  nixantic.sources.version-control.blocks."current-branch" =
    { scope }:
    {
      content = ''
        Current branch / change context: `${
          scope.forSetting "versionControl.mode" {
            jj = "!`jj-current-branch`";
            git = "!`git branch --show-current`";
          }
        }`
      '';
    };
}
