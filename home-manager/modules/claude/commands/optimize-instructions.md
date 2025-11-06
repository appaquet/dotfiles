---
name: optimize-instructions
description: Optimize instruction file using latest best practices
argument-hint: [file-path]
---

# Optimize Instructions

Optimize the specified instruction file using latest Claude prompt engineering best practices.

Target file: `$ARGUMENTS`

## Instructions

### Phase 1: Analysis (DO NOT MODIFY FILES)

1. **Fetch latest best practices**:
   - Search web for latest Claude prompt engineering best practices
   - Fetch Claude Code documentation on instruction writing
   - Review Anthropic's official prompt engineering guidelines

2. **Deep analysis**:
   - Read target file and all linked files (@docs references)
   - Identify optimization opportunities:
     * Token efficiency (verbose phrases, redundancy, filler words)
     * Structure (lists vs prose, clarity, organization)
     * Clarity (imperative mood, explicit instructions, examples)
     * Cross-file redundancy
   - Compare against best practices from step 1

3. **Report findings**:
   - List specific issues found with examples
   - Explain what optimizations would be applied
   - Estimate token savings
   - Show before/after examples for key changes

**STOP HERE** - Wait for user approval before proceeding to Phase 2

### Phase 2: Implementation (Only after user approval)

4. **Apply optimizations**:
   - Create jj change
   - Remove meta-commentary and verbose explanations
   - Consolidate redundant examples (1 per rule)
   - Convert prose to lists/tables where clearer
   - Use imperative mood ("Do X" not "You should do X")
   - Front-load critical rules
   - Single emphasis level (CRITICAL/Important/plain)
   - Preserve all salient information
   - Commit changes

5. **Report results**:
   - Final metrics (tokens saved, key improvements)
   - Notify completion
