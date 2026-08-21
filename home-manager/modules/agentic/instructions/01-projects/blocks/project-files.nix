{
  nixantic.sources.projects.blocks."project-files" =
    { scope }:
    {
      content = scope.forHarness {
        pi = ''
          Project files: run `agentic-proj-docs` with the shell tool, then use its output as the project-file state.
        '';
        default = ''
          Project files:
          ```
          !`agentic-proj-docs`
          ```
        '';
      };
    };
}
