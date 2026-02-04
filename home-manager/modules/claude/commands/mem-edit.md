---
name: mem-edit
description: Entry point for instruction file changes - edits, fixes, optimization
argument-hint: [files or description]
---

# Edit Instructions

User-facing command for instruction file changes. Analyzes first, then gates before applying

Target: `$ARGUMENTS`

## Instructions

1. 🔳 Load skills
    * Load the `mem-editing` right away. This will be needed for analysis and application
    * Load the `ctx-plan` command to ensure proper planning steps

1. 🔳 Ensure scope identified
   If target unclear, use `AskUserQuestion` to clarify

1. 🔳 Analyze with mem-editing skill
   * Load the `mem-editing` skill
   * Load all of its files
   * Load some context around the target instruction file(s)
     * Load surrounding instructions/commands/skills/agents to understand the pattern and style
   * Using its instructions, analyse the requested instruction file(s)
     * It's important to follower the `mem-editing` skill, but the surrounding style also has to be considered

1. **STOP AND WAIT** - Await `/proceed` confirmation before applying changes

1. 🔳 Apply with mem-editing skill
