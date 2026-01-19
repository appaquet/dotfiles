---
name: proj-tidy
description: Validate and fix project doc consistency against standard structure
---

# Project Tidy

Validate current project doc against the standard structure defined in @docs/project-doc.md and
propose fixes for any inconsistencies.

Current project files: !`claude-proj-docs`

## Instructions

1. Load the standard structure from @docs/project-doc.md.

2. Read current project doc (main `00-*.md` and any sub-docs).

3. Validate against standard structure:
   * Section names match expected names
   * Sections appear in correct order
   * Section content follows documented format (bullet style, checkbox format, emoji markers, etc.)
   * Cross-references between docs are valid

4. Check requirement/task status consistency:
   * Parse requirements with phase annotations (e.g., `(Phase 1)`, `(Phase: Auth)`)
   * Compare requirement status markers against linked phase completion state
   * Report mismatches (e.g., requirement marked ⬜ but linked phase is ✅)

5. Check for completable phases:
   * Identify phases where all tasks are `[x]` but phase header is not ✅
   * Report these as candidates for completion

6. Present findings:
   * List all detected issues grouped by category
   * For each issue, show current state and proposed fix
   * Use `AskUserQuestion` to confirm before applying any fixes

7. Apply approved fixes and report changes made.
