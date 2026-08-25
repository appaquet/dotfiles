{
  nixantic.sources.projects.skills."project-docs" = {
    kind = "directory";
    main =
      { scope }:
      {
        description = "Read, interpret, create, update, plan and maintain project and phase documentation.";
        content = ''
          # Project documentation

          ${scope.blocks."project-doc-lifecycle".content}

          ${scope.blocks."project-doc-project".content}

          ${scope.blocks."project-doc-phase".content}
        '';
      };
    files = { };
  };
}
