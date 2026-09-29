{
  nixantic.sources.main.blocks."pre-flight" =
    { scope }:
    let
      toolLine = "* Track each 🔳 step / task as you go, using appropriate task tools if available";
    in
    {
      heading = "Pre-flight instructions";

      content = ''
        Before executing instructions of any command/skill/agent instructions:
      '';

      tag = "pre-flight";
      taggedContent = ''
        * ${scope.blocks."task-management".preFlightRecall}
        * ${scope.blocks."sub-agents-workflows".preFlightRecall}
        * ${scope.blocks."project-doc-recall".preFlightRecall}
      '';

      reference = ''
        Before proceeding with any instructions above, you NEED to follow <pre-flight> instructions. 
        ${toolLine}
        * Follow sub-agents workflows
        * Use & maintain freshness/accuracy of project/phase docs. Use ${
          scope.skills."project-docs".reference
        }.
      '';
      injectReferenceIntoCommands = true;
    };
}
