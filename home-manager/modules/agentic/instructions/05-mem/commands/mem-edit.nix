{
  nixantic.sources.instruction-authoring.commands."mem-edit" =
    { scope }:
    {
      description = "Entry point for instruction file changes - edits, fixes, optimization";

      argumentHint = "[files or description]";

      content = ''
        Goal: user-facing command for instruction file changes.

        Target: `$ARGUMENTS`

        ## Instructions

        1. 🔳 Load `${scope.skills."mem-writing".name}` skill

        2. 🔳 Ensure scope identified
           If unclear, use `AskUserQuestion`

        3. 🔳 Analyze target files
           * Apply ${scope.skills."mem-writing".reference} guidelines for analysis & proposal

        4. ${scope.blocks."engagement-gate".gate}
      '';
    };
}
