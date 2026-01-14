---
name: proj-split
description: Split a phase from main project doc into a numbered sub-doc
argument-hint: [phase-name]
---

# Project Split

Split a phase from the main project doc (`00-*.md`) into a numbered sub-doc in the same directory.
Supports both active and completed phases - use retroactively to archive detailed history.

Phase: $ARGUMENTS

Current project files: !`ls proj/ 2>/dev/null || echo "No project files"`

## Instructions

1. If project doc not loaded/clear from context, run `/ctx-load` first.

2. If phase not specified and not clear from context, list phases from TODO section and use
   `AskUserQuestion`.

3. Determine phase name: 2-3 words describing the phase (e.g., "auth-validation", "api-endpoints").

4. Determine the next available number:
   - List existing sub-docs: `01-*.md`, `02-*.md`, etc.
   - If inserting between existing docs, **ask user** which approach:
     - **Sub-numbering**: Use `01a-`, `01b-`, etc. (no renaming needed)
     - **Resequence**: Rename existing docs to make room (updates all cross-references)

5. Create the sub-doc with:
   * Context (brief, reference parent `00-<project-name>.md` via relative link)
   * Files (relevant to this phase)
   * TODO (moved from main doc - preserve all details including completed items)

6. Update main project doc:
   * Replace phase TODOs with header + link + summary blurb (2-3 sentences):
     ```
     ### Phase: Name
     [01-phase-name.md](01-phase-name.md)

     Brief summary of what this phase accomplishes. Key deliverables or changes.
     ```
   * Summary should be maintained even as phase progresses - update when scope changes

7. If resequencing was chosen:
   * Rename docs in order (e.g., `02-*.md` → `03-*.md`)
   * Update all cross-references in all project docs (main + sub-docs)
   * Report all renamed docs to user

8. NEVER jump to implementation. Report changes and wait for instruction.
