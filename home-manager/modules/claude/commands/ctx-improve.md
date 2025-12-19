---
name: ctx-improve
description: Improve context by asking clarifying questions
---

# Improve Context

Ultrathink. Use sub-agents (Task tool) for codebase exploration if needed.

Use the Understanding Checklist to verify completeness.

## Instructions

1. Research full context: task, repository, documentation.
   * Consider launching sub-agents (Task tool) to explore codebase, find patterns
   * Search web for external dependencies or unfamiliar concepts if needed

2. Use `AskUserQuestion` to clarify requirements. 
   Research and ask until 10/10 understanding.

3. Update project doc with new context gathered (if working on a planned task).

4. **STOP** - Use `AskUserQuestion` to ask if user wants to proceed to implementation.
