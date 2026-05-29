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

        * Your context is precious, use ${scope.blocks."sub-agents-workflows".reference}

        * ALWAYS use project & phase docs to plan and track work as per project-doc.md rules, using the
          proper project editing skills
      '';

      reference = "Imperative follow <pre-flight> instructions before doing anything";

      injectReferenceIntoCommands = true;
    };
}
