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
| 3 | Await /go to proceed | Analysis complete, await user confirmation before modifying |
| 4 | Apply with mem-editing skill | Run `mem-editing` skill tasks 5-7 (jj change, apply, commit) |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure scope identified** - If target unclear, use `AskUserQuestion` to clarify.

2. **Analyze with mem-editing skill**:
   * Load the `mem-editing` skill
   * Execute tasks 1-4: scope, gather context, analyze, report findings
   * Show before/after for proposed changes

3. **STOP** - Await `/go` confirmation before applying changes.

4. **Apply with mem-editing skill**:
   * Execute tasks 5-7: ensure jj change, apply changes, commit
