---
name: mem-edit
description: Entry point for instruction file changes - edits, fixes, optimization
argument-hint: [files or description]
---

# Modify Instructions

Edit instruction files with full analysis workflow. Use for any instruction change: optimization,
bug fixes, adding rules, refactoring.

Target: `$ARGUMENTS` (files or description of change)

## Instructions

### Phase 1: Analysis (DO NOT MODIFY FILES)

1. Identify scope:
   * If target is a file path → that's the primary file
   * If target is a description → identify which file(s) need changes

2. Load instruction-writer skill.

3. Read primary file(s) and all linked files (@docs references)

4. Search for related files:
   * Grep for key concepts/terms in other instruction files
   * Check commands, skills, docs that reference the same concepts

5. Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!):
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.
   * Think through each instruction as a fresh agent - what could be misinterpreted?
   * Check for redundancy and conflicts ACROSS files
   * Identify all changes needed (may span multiple files)
   * Apply instruction-writer best practices

6. Report findings:
   * Files affected
   * Before/after for each change
   * Rationale

**Use AskUserQuestion** to confirm before Phase 2

### Phase 2: Implementation (Only after approval)

7. Create jj change
8. Apply changes preserving all salient information
9. Verify consistency across all affected files
10. Commit changes
