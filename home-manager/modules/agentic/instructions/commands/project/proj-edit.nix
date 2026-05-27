{ scope }:
{
  description = "Edit project and phase docs with structure validation";

  argumentHint = "[operation or file]";

  content = ''
    Goal: user-facing command for project/phase doc changes. Analyze first, then gates before applying

    Target: `$ARGUMENTS`

    ## Instructions

    1. 🔳 Load `proj-editing` skill

    2. 🔳 Ensure scope identified
       - If target unclear, use `AskUserQuestion` to clarify what operation:
         - Create project doc
         - Create phase doc
         - Update task status
         - Update phase status
         - Validate structure

    3. 🔳 Analyze current state
       - Read relevant project/phase docs
       - Identify changes needed

    4. 🔳 Report proposed changes
       - Show before/after for each change

    5. **GATE**: Await `/proceed` before applying changes

    6. 🔳 Apply with proj-editing skill
  '';
}
