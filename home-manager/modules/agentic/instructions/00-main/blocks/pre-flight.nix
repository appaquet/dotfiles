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
        * ${scope.blocks."task-management".preFlightRecall}
        * ${scope.blocks."sub-agents-workflows".preFlightRecall}
        * ${scope.blocks."project-doc-recall".preFlightRecall}
      '';

      reference = ''
        Before proceeding with any instructions above, you NEED to follow <pre-flight> instructions. 
        * Use task tool (`${scope.harness.tools.taskCreate}`) for each 🔳 step
        * Follow sub-agents workflows
        * Maintain project docs and stricly follow instructions to maintain their freshness and accuracy
      '';
      injectReferenceIntoCommands = true;
    };
}
