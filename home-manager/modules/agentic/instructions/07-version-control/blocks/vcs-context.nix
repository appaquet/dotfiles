{
  nixantic.sources.version-control.blocks."vcs-context" =
    { scope }:
    {
      content = scope.forHarness {
        pi = ''
          Run `agentic-vcs-context` with the shell tool, then use its stdout as the current version control context.
        '';
        default = ''
          Current version control context: !`agentic-vcs-context`
        '';
      };
    };
}
