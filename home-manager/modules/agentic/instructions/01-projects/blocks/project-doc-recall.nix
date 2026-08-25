{
  nixantic.sources.projects.blocks."project-doc-recall" =
    { scope }:
    {
      preFlightRecall = "ALWAYS use project and phase documents to plan and track work, unless explicitly mentioned using ${
        scope.skills."project-docs".reference
      }";
      content = "";
    };
}
