{
  nixantic.sources.main.blocks."pre-flight" =
    { scope }:
    {
      heading = "Pre-flight instructions";

      content = ''
        Before executing instructions of any command/skill/agent instructions:
      '';

      tag = "pre-flight";
      taggedContent = ''
        * ${scope.blocks."task-management".preFlightContent}
        * ${scope.blocks."sub-agents-workflows".preFlightContent}
        * ${scope.blocks."project-doc-recall".preFlightContent}
      '';

      # Injected in each command
      reference = ''
        Before proceeding with any instructions above, you NEED to follow <pre-flight> instructions. 
        * Track the work as you go, using task tools where appropriate
        * Follow sub-agents workflows
        * Use & maintain freshness/accuracy of project/phase docs. Use ${
          scope.skills."project-docs".reference
        }.
      '';
      injectReferenceIntoCommands = true;
    };
}
