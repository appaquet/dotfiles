{
  nixantic.sources.root-instructions.blocks."pre-flight" =
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

      reference = "Imperative follow <pre-flight> instructions before doing anything";
      injectReferenceIntoCommands = true;
    };
}
