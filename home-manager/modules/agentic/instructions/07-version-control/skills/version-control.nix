{
  nixantic.sources.version-control.skills."version-control" = {
    kind = "directory";
    main =
      { scope }:
      {
        description = "Use this skill the moment you are about to run a version-control command (jj), including need to look at repository state: status, log, diffs, commits, branches, merges, rebase intent, etc.";
        content = ''
          # Version Control (Jujutsu)

          ${scope.blocks."version-control-jj".content}
        '';
      };
    files = { };
  };
}
