{
  nixantic.sources.version-control.blocks."current-change-files" =
    { scope }:
    {
      content = ''
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
}
