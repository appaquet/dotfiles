{ scope }:
{
  description = "Entry point for instruction file changes - edits, fixes, optimization";

  argumentHint = "[files or description]";

  content = ''
    Goal: user-facing command for instruction file changes. Analyzes first, then gates before applying

    Target: `$ARGUMENTS`

    ## Instructions

    1. 🔳 Load skills using the `Skill` tool
        * `mem-editing` - editing guidelines and supporting files
        * `ctx-plan` - planning steps

    2. 🔳 Ensure scope identified
       If target unclear, use `AskUserQuestion` to clarify

    3. 🔳 Analyze target files
       * Load context around the target instruction file(s)
         * Load surrounding instructions/commands/skills/agents to understand the pattern and style
       * Apply `mem-editing` guidelines: check for ambiguity, cross-file conflicts, redundancy
       * Use the `<deep-thinking>` procedure

    4. **GATE**: Await `/proceed` before applying changes

    5. 🔳 Apply changes
       * Follow `mem-editing` guidelines during edits
       * Verify consistency across affected files

    ${scope.blocks.pre-flight.reference}
  '';
}
