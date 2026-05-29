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
         If target unclear, use `AskUserQuestion` to clarify

      3. 🔳 Analyze target files
         * Load context around the target instruction file(s)
           * Load surrounding instructions/commands/skills/agents to understand the pattern and style
         * If general instructions, changes should be done in nix files (~/dotfiles/.../instructions/**/*.nix), not in rendered version
         * Apply `mem-editing` guidelines
         * Use the `<deep-thinking>` procedure

      4. **GATE**: Await `/proceed` before applying changes

      5. 🔳 Apply changes
         * Follow `mem-editing` guidelines during edits
         * Verify consistency across affected files
    '';
  };
}
