---
name: proj-edit
description: Edit project and phase docs with structure validation
argument-hint: [operation or file]
---

# Edit Project Docs

User-facing command for project/phase doc changes. Validates structure, then gates before applying.

Target: `$ARGUMENTS`

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure operation identified | Skip if $ARGUMENTS specifies operation, else ask |
| 2 | Load proj-editing skill | Load skill for structure rules |
| 3 | Analyze current state | Read relevant docs, identify what needs to change |
| 4 | Report proposed changes | Show before/after for each change |
| 5 | Await /proceed to proceed | Analysis complete, await user confirmation |
| 6 | Apply changes | Edit docs following proj-editing skill rules |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure operation identified** - If target unclear, use `AskUserQuestion` to clarify what operation:
   * Create project doc
   * Create phase doc
   * Update task status
   * Update phase status
   * Validate structure

2. **Load proj-editing skill** - The skill provides:
   * Key structures (XML blocks)
   * Core rules (tasks in phase docs, etc.)
   * Operation-specific steps

3. **Analyze current state** - Read relevant project/phase docs, identify changes needed.

4. **Report proposed changes** - Show before/after for each change.

5. **STOP** - Await `/proceed` confirmation before applying changes.

6. **Apply changes** - Follow proj-editing skill operations, verify consistency.
