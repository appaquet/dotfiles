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
        * Following Task management guidelines, create tasks for 🔳 annotated instructions and strictly
          follow the task management guidelines for executing and completing them. No tasks is trivial
          enough to skip the task management process

        * Your context is precious, use ${scope.blocks."sub-agents-workflows".reference} 

        * ALWAYS use project & phase docs to plan and track work as per project-doc.md rules, using the
          proper project editing skills

      '';

      reference = "Imperative follow <pre-flight> instructions before doing anything";
    };
}
