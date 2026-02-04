---
name: mem-edit
description: Entry point for instruction file changes - edits, fixes, optimization
argument-hint: [files or description]
---

# Edit Instructions

User-facing command for instruction file changes. Analyzes first, then gates before applying.

Target: `$ARGUMENTS`

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure scope identified | Skip if $ARGUMENTS is file path, else ask |
| 2 | Analyze with mem-editing skill | Load `mem-editing` skill, run tasks 1-4 (scope, context, analyze, report) |
| 3 | Await /proceed to proceed | Analysis complete, await user confirmation before modifying |
| 4 | Apply with mem-editing skill | Run `mem-editing` skill tasks 5-7 (jj change, apply, commit) |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure scope identified**
   If target unclear, use `AskUserQuestion` to clarify.

2. **Analyze with mem-editing skill**
   * Load the `mem-editing` skill
   * Using its instructions, analyse the requested instruction file(s)

3. **STOP** - Await `/proceed` confirmation before applying changes.

4. **Apply with mem-editing skill**
