---
name: pr-split
description: Split a phase from PR.md into a sub-file (pr-<subphase>.md)
argument-hint: [phase-name]
---

# PR Split

Split a phase from PR.md into a dedicated sub-file.

Phase (may be empty if clear from context):
```markdown
$ARGUMENTS
```

1. If PR.md not loaded/clear from context, run `/ctx-load` first.

2. If phase not specified or clear from context, list phases from PR.md TODO section and use
   `AskUserQuestion`.

3. Create `pr-<phase>.md` with:
   * Context (brief, reference parent PR.md)
   * Files (relevant to this phase)
   * TODO (moved from PR.md)

4. Update `PR.md`:
   * Replace phase TODOs with: `See [pr-<phase>.md](pr-<phase>.md)`
   * Keep phase header for navigation

5. NEVER jump to implementation after. Report changes and wait for instruction.
