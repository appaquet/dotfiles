{
  nixantic.sources.version-control.skills."version-control" = {
    kind = "directory";
    main =
      { scope }:
      scope.forSetting "versionControl.mode" {
        jj = {
          description = "Use this skill whenever version-control work is needed with Jujutsu (`jj`), including repository state and status, diffs, commits, branches, merges, and rebase intent.";
          content = ''
            # Version Control (Jujutsu)

            ${scope.blocks."version-control-jj".content}
          '';
        };
        git = {
          description = "Use this skill whenever version-control work is needed with Git (`git`), including repository state and status, diffs, commits, branches, merges, and rebase intent.";
          content = ''
            # Version Control (Git)

            ${scope.blocks."version-control-git".content}
          '';
        };
      };
    files = { };
  };
}
