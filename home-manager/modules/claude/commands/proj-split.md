---
name: proj-split
description: Create a new phase doc for an additional phase
argument-hint: [phase-name]
---

# Create Phase Doc

Create a new phase doc for an additional phase. First phase doc is created with `/proj-init`;
use this command for subsequent phases.

Phase: $ARGUMENTS

Current project files: !`claude-proj-docs`

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure project doc loaded | Skip if in context, else run /ctx-load |
| 2 | Ensure phase identified | Skip if $ARGUMENTS provided, else ask |
| 3 | Determine phase name | 2-3 words describing the phase |
| 4 | Determine phase doc number | Next available (02, 03, ...) or sub-number if inserting |
| 5 | Create phase doc | Context, Tasks, Files sections per `<phase-doc-sections>` |
| 6 | Update project doc | Add phase reference to Phases section with link + summary |
| 7 | Resequence if needed | Ask user for approach if inserting |
| 8 | Await /go to proceed | Phase doc created, await user confirmation |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure project doc loaded** - If project doc not loaded/clear from context, run `/ctx-load` first.

2. **Ensure phase identified** - If phase not specified and not clear from context, list phases from
   Phases section and use `AskUserQuestion`.

3. **Determine phase name** - 2-3 words describing the phase (e.g., "auth-validation", "api-endpoints").
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Think about what name captures the phase's purpose

4. **Determine phase doc number** - List existing phase docs: `01-*.md`, `02-*.md`, etc.
   * If inserting between existing docs, **ask user** which approach:
     * **Sub-numbering**: Use `01a-`, `01b-`, etc. (no renaming needed)
     * **Resequence**: Rename existing docs to make room (updates all cross-references)

5. **Create phase doc** with:
   * Context (brief, reference project doc `00-<project-name>.md` via relative link)
   * Tasks (all `[ ]` items for this phase)
   * Files (relevant to this phase)
   * **Requirements**: Only if expanding on project doc requirements. Phase docs NEVER introduce new
     top-level requirements - reference existing ones via `(R5)` in tasks or detail them as `R5.A`.
     If no expansion needed, omit Requirements section entirely.
   * Follow `<phase-doc-sections>` structure and order

6. **Update project doc**:
   * Add phase reference to Phases section with header + link + summary blurb (2-3 sentences):
     ```
     ### 🔄 Phase: Name
     [02-phase-name.md](02-phase-name.md)

     Brief summary of what this phase accomplishes. Key deliverables or changes.
     ```
   * Update summary as phase progresses

7. **Resequence if needed**:
   * Rename docs in order (e.g., `02-*.md` → `03-*.md`)
   * Update all cross-references in all docs (project + phase docs)
   * Report all renamed docs to user

8. **STOP** - Report changes and wait for instruction. Tell user to use `/go` when ready to proceed.
