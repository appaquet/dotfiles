---
name: proj-tidy
description: Validate and fix project doc consistency against standard structure
context: fork
---

# Project Tidy

Validate current project doc against the standard structure defined in @~/.claude/docs/project-doc.md and
propose fixes for any inconsistencies.

Current project files: !`claude-proj-docs`

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Load standard structure | Read project-doc.md for reference |
| 2 | Read project docs | Main doc + all sub-docs |
| 3 | Validate structure | Check section names, order, format, cross-refs. For each problem, add sub-task "Fix: [issue]" |
| 4 | Check requirement consistency | Verify no overlaps, phase annotations correct, sub-doc R-numbers derive from parent |
| 5 | Check completable items | Flag phases/requirements where all tasks done but status not ✅ |
| 6 | Present findings | Group by category with proposed fixes |
| 7 | Apply fixes | After user confirmation per issue |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Load standard structure** from @~/.claude/docs/project-doc.md.

2. **Read project docs** - Read current project doc (main `00-*.md` and any sub-docs).

3. **Validate structure** against standard:
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Section names match expected names
   * Sections appear in correct order
   * Section content follows documented format (bullet style, checkbox format, emoji markers, etc.)
   * Cross-references between docs are valid
   * For each problem found, add sub-task "Fix: [issue]"

4. **Check requirement consistency**:
   * Read and understand ALL requirements. Flag overlapping topics as potential conflicts.
   * Parse requirements with phase annotations (e.g., `(Phase: Auth)`)
   * Detect sub-doc requirements that don't derive from parent R-numbers (e.g., sub-doc has `R1:`
     instead of `R5.A:`). Phase docs should never introduce new top-level requirements.
   * Verify main doc references sub-doc details when sub-doc expands requirements

5. **Check completable items** (per @~/.claude/docs/project-doc.md, user decides ✅):
   * Flag phases where all tasks are `[x]` but phase is still 🔄
   * Flag requirements where all linked work is done but requirement is still 🔄
   * These are candidates - use `AskUserQuestion` before marking ✅

6. **Present findings**:
   * List all detected issues grouped by category
   * For each issue, show current state and proposed fix
   * Use `AskUserQuestion` to confirm before applying any fixes

7. **Apply fixes** after user confirmation per issue.
