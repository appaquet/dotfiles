{
  nixantic.sources.instruction-authoring.commands."mem-edit" = {
    description = "Entry point for instruction file changes - edits, fixes, optimization";

    argumentHint = "[files or description]";

    content = ''
      Goal: user-facing command for instruction file changes.

      Target: `$ARGUMENTS`

      ## Instructions

      1. 🔳 Load `mem-editing` skill

      2. 🔳 Ensure scope identified
         If unclear, use `AskUserQuestion`

      3. 🔳 Analyze target files
         * Apply `mem-editing` guidelines for analysis & proposal

      4. **STOP**: User will need to use `/proceed` to apply changes.
    '';
  };
}
