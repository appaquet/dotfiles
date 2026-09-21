{
  nixantic.sources.version-control.blocks."vcs-context" =
    { scope }:
    let
      workspacePolicy = ''
        Jujutsu repositories can use multiple workspaces. If the current version control context reports `JJ workspace: <name>`, work exclusively in that workspace for the task. Perform all repository work there. Do not use `default` or another workspace unless AP explicitly directs it. If later version-control output reports another workspace, STOP and ask.
      '';
    in
    {
      content = scope.forHarness {
        pi = ''
          Run `agentic-vcs-context` with the shell tool, then use its stdout as the current version control context.
          ${workspacePolicy}
        '';
        default = ''
          Current version control context: !`agentic-vcs-context`
          ${workspacePolicy}
        '';
      };
    };
}
