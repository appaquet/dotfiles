{
  nixantic.sources.version-control.blocks."vcs-context" =
    { scope }:
    {
      content = scope.forHarness {
        pi = ''
          Run `${
            scope.forSetting "versionControl.mode" {
              jj = "agentic-vcs-context jj";
              git = "agentic-vcs-context git";
            }
          }` with the shell tool, then use its stdout as the current version control context.
        '';
        default = ''
          Current version control context: ${
            scope.forSetting "versionControl.mode" {
              jj = "!`agentic-vcs-context jj`";
              git = "!`agentic-vcs-context git`";
            }
          }
        '';
      };
    };
}
