{
  nixantic.sources.version-control.skills."version-control" = {
    kind = "directory";
    main =
      { scope }:
      scope.forSetting "versionControl.mode" {
        jj = {
          description = "Use this skill the moment you are about to run a version-control command (jj/git), including need to look at repository state: status, log, diffs, commits, branches, merges, rebase intent, etc.";
          content = ''
            # Version Control (Jujutsu)

            ${scope.blocks."version-control-jj".content}
          '';
        };

        git = {
          description = "Use this skill whenever version-control work is needed with git, including need to look at repository state: status, log, diffs, commits, branches, merges, rebase intent, etc.";
          content = ''
            # Version Control (Git)

            ${scope.blocks."version-control-git".content}
          '';
        };
      };
    files = { };
  };
}
