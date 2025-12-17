---
name: pr-split
description: Split a phase from PR.md into a sub-file (PR-<phase-name>.md)
argument-hint: [phase-name]
---

# PR Split

Split a phase from PR.md into a dedicated sub-file in the **same directory** as PR.md.
Supports both active and completed phases - use retroactively to archive detailed history.

Phase (may be empty if clear from context):
```markdown
$ARGUMENTS
```

1. If PR.md not loaded/clear from context, run `/ctx-load` first.

2. If phase not specified or clear from context, list phases from PR.md TODO section and use
   `AskUserQuestion`.

3. Determine phase name: 2-3 words describing the phase (e.g., "auth-validation", "api-endpoints").

4. Create `PR-<phase-name>.md` in **same directory as PR.md** (not repo root) with:
   * Context (brief, reference parent PR.md)
   * Files (relevant to this phase)
   * TODO (moved from PR.md - preserve all details including completed items)

5. Update `PR.md`:
   * Replace phase TODOs with header + link to sub-file:
     ```
     ### 🔄 Phase: Name
     [PR-<phase-name>.md](PR-<phase-name>.md)
     ```
   * Phase indicators: `⬜` To Do | `🔄` In Progress | `✅` Done

6. NEVER jump to implementation. Report changes and wait for instruction.
