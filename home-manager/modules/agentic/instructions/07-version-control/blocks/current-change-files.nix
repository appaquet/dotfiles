{
  nixantic.sources.version-control.blocks."current-change-files" =
    { scope }:
    {
      content = scope.forHarness {
        pi = ''
          Run `jj-diff-branch --stat` with the shell tool, then use its stdout as changed files in the current work.
        '';
        default = ''
          Changed files in current work:
          ```
          !`jj-diff-branch --stat`
          ```
        '';
      };
    };
}
