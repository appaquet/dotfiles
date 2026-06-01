{
  nixantic.sources.instruction-authoring.commands."mem-edit" = {
    description = "Entry point for instruction file changes - edits, fixes, optimization";

    argumentHint = "[files or description]";

    content = ''
      Goal: user-facing command for instruction file changes. Analyzes first, then gates before applying

      Target: `$ARGUMENTS`

      ## Instructions

      1. 🔳 Load `mem-editing` skill

      2. 🔳 Ensure scope identified
         If unclear, use `AskUserQuestion`

      3. 🔳 Analyze target files
         * Apply `mem-editing` guidelines for analysis & proposal

      4. **GATE**: Await `/proceed` before applying changes

      5. 🔳 Apply changes
         * Follow `mem-editing` guidelines during edits
    '';
  };
}
