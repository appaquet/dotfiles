---
name: pr-desc
description: Generate detailed changelog-style summary of branch changes
model: sonnet
---

# PR Description

Generate a detailed changelog-style summary of branch changes for reference. Uses project context
and branch diff to create multi-level breakdown.

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Ensure context loaded
   - Run `/ctx-load` to load project context (project doc, branch state, recent commits)

3. 🔳 Analyze changes
   - Get changed files: `jj-diff-branch --stat`
   - Read diffs for understanding: `jj-diff-branch --git`
   - Use the <deep-thinking> procedure
   - If user specified a focus area, prioritize those components

4. 🔳 Generate report in one message, without any following messages:
   - **Per-component breakdown**:
     - Group changes by logical component (directory, module, or feature area)
     - For each component, list changes by category:
       - **Added**: New files, features, capabilities
       - **Changed**: Modified behavior, refactored code
       - **Fixed**: Bug fixes, corrections
       - **Removed**: Deleted files, deprecated features
     - Skip empty categories
    
   - **Summary** (after per-component breakdown):
     - 2-3 sentence paragraph: what the PR accomplishes, why, and any notable cross-cutting
       technical detail (e.g., engine fixes that enable the feature)
     - Followed by 3-5 thematic bullet lines: group by what was done (not by directory),
       each 1-2 lines describing a logical change spanning multiple layers
     - Use `human-writer` skill tone — no AI filler or superlatives

