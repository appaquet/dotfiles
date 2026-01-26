---
name: ctx-improve
description: Improve context by asking clarifying questions
---

# Improve Context

Use the full understanding checklist and verify our full (10/10) understanding of the task at hand.

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. If 10/10 understanding, you can tell me and stop here.
   Otherwise, tell me your current understanding of the task on 10 scale.

2. Research full context: files, task, repository, documentation.
   * Consider launching sub-agents (Task tool) to explore codebase, find patterns
   * Search web for external dependencies or unfamiliar concepts if needed
   * Think about requirements, constraints, edge cases
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.

3. Use `AskUserQuestion` to clarify requirements.
   Research and ask until 10/10 understanding.
   * Clarification ≠ approval—continue to jump to implementation

4. Update project doc with new context gathered (if working on a planned task).
   * Organize requirements into MoSCoW priorities (Must/Should/Could/Won't Have)
   * Number requirements (R1, R2, R1.1) for Tasks traceability

5. **STOP** - Tell user to use `/go` when ready to proceed with implementation.
