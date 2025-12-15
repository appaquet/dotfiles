---
name: mem-optimize
description: Optimize instruction file using latest best practices
argument-hint: [file-path]
---

# Optimize Instructions

Optimize the specified instruction file using the instruction-writer skill.

Target file: `$ARGUMENTS`

## Instructions

Use the instruction-writer skill to apply best practices.

### Phase 1: Analysis (DO NOT MODIFY FILES)

1. Read target file and all linked files (@docs references)
2. Apply instruction-writer skill's optimization workflow to identify issues
3. Report findings with before/after examples and estimated token savings

**Use AskUserQuestion** to ask if user wants to proceed to Phase 2

### Phase 2: Implementation (Only after user approval)

4. Create jj change
5. Apply optimizations preserving all salient information
6. Commit changes
7. Report results (tokens saved, key improvements)
