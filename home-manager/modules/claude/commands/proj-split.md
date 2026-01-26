---
name: proj-split
description: Split a phase from main project doc into a numbered sub-doc
argument-hint: [phase-name]
---

# Project Split

Split a phase from the main project doc (`00-*.md`) into a numbered sub-doc in the same directory.
Supports both active and completed phases - use retroactively to archive detailed history.

Phase: $ARGUMENTS

Current project files: !`claude-proj-docs`

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure project doc loaded | Skip if in context, else run /ctx-load |
| 2 | Ensure phase identified | Skip if $ARGUMENTS provided, else ask |
| 3 | Determine phase name | 2-3 words describing the phase |
| 4 | Determine sub-doc number | Next available (01, 02, ...) or sub-number if inserting |
| 5 | Create sub-doc | Context, Files, Tasks sections |
| 6 | Update main doc | Replace phase tasks with link + summary |
| 7 | Resequence if needed | Ask user for approach if inserting |
| 8 | Await /go to proceed | Split complete, await user confirmation |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure project doc loaded** - If project doc not loaded/clear from context, run `/ctx-load` first.

2. **Ensure phase identified** - If phase not specified and not clear from context, list phases from
   Tasks section and use `AskUserQuestion`.

3. **Determine phase name** - 2-3 words describing the phase (e.g., "auth-validation", "api-endpoints").
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Think about what name captures the phase's purpose

4. **Determine sub-doc number** - List existing sub-docs: `01-*.md`, `02-*.md`, etc.
   * If inserting between existing docs, **ask user** which approach:
     * **Sub-numbering**: Use `01a-`, `01b-`, etc. (no renaming needed)
     * **Resequence**: Rename existing docs to make room (updates all cross-references)

5. **Create sub-doc** with:
   * Context (brief, reference parent `00-<project-name>.md` via relative link)
   * Files (relevant to this phase)
   * Tasks (moved from main doc - preserve all details including completed items)
   * **Requirements**: Only if expanding on main doc requirements. Sub-docs NEVER introduce new
     top-level requirements - reference existing ones via `(R5)` in tasks or detail them as `R5.A`.
     If no expansion needed, omit Requirements section entirely.

6. **Update main doc**:
   * Replace phase tasks with header + link + summary blurb (2-3 sentences):
     ```
     ### Phase: Name
     [01-phase-name.md](01-phase-name.md)

     Brief summary of what this phase accomplishes. Key deliverables or changes.
     ```
   * Summary should be maintained even as phase progresses - update when scope changes
   * Update requirement phase annotations to reference sub-doc name (e.g., `(Phase 1)` → `(Phase: Auth)`)

7. **Resequence if needed**:
   * Rename docs in order (e.g., `02-*.md` → `03-*.md`)
   * Update all cross-references in all project docs (main + sub-docs)
   * Report all renamed docs to user

8. **STOP** - Report changes and wait for instruction. Tell user to use `/go` when ready to proceed.
