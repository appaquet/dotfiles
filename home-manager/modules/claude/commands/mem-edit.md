---
name: mem-edit
description: Entry point for instruction file changes - edits, fixes, optimization
argument-hint: [files or description]
---

# Modify Instructions

Edit instruction files with full analysis workflow. Use for any instruction change: optimization,
bug fixes, adding rules, refactoring.

Target: `$ARGUMENTS` (files or description of change)

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure scope identified | Skip if $ARGUMENTS is file path, else ask |
| 2 | Load instruction-writer skill | Reference for best practices |
| 3 | Gather context | Read primary files, linked files, grep for related. For each related file, add sub-task "Read: [file]" |
| 4 | Analyze | Check conflicts, redundancy across files. Think as fresh agent - what could be misinterpreted? |
| 5 | Report findings | Files affected, before/after for each change, rationale |
| 6 | Await /go to proceed | Analysis complete, await user confirmation before modifying |
| 7 | Create jj change | New change for edits |
| 8 | Apply changes | Edit files, verify consistency across all affected |
| 9 | Commit | Message describing changes |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

### Phase 1: Analysis (tasks 1-6, DO NOT MODIFY FILES)

1. **Ensure scope identified**:
   * If target is a file path → that's the primary file
   * If target is a description → identify which file(s) need changes

2. **Load instruction-writer skill**.

3. **Gather context** - Read primary file(s) and all linked files (@docs references):
   * Search for related files
   * Grep for key concepts/terms in other instruction files
   * Check commands, skills, docs that reference the same concepts
   * For each related file found, add sub-task "Read: [file]"

4. **Analyze** thoroughly (ultra, deeply, freakingly, super ultrathink!):
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Think through each instruction as a fresh agent - what could be misinterpreted?
   * Check for redundancy and conflicts ACROSS files
   * Identify all changes needed (may span multiple files)
   * Apply instruction-writer best practices

5. **Report findings**:
   * Files affected
   * Before/after for each change
   * Rationale

6. **STOP** - Await /go confirmation before Phase 2.

### Phase 2: Implementation (tasks 7-9, only after /go)

7. **Create jj change** - New change for edits.

8. **Apply changes** - Preserve all salient information, verify consistency across all affected files.

9. **Commit** - Commit changes with descriptive message.
