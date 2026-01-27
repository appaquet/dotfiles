---
name: ctx-improve
description: Improve context by asking clarifying questions
---

# Improve Context

Use the full understanding checklist and verify our full (10/10) understanding of the task at hand.

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Check current understanding | Exit early if already 10/10 |
| 2 | Research context | Explore files, documentation, web. For each unknown, add sub-task to investigate. |
| 3 | Ask clarifying questions | Use AskUserQuestion for each ambiguity. Continue until 10/10. |
| 4 | Update project doc | Add new context to project doc if exists |
| 5 | Await /go to proceed | Research complete, await user confirmation |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Check current understanding** - If 10/10 understanding, tell me and stop here.
   Otherwise, tell me your current understanding on a 10 scale.

2. **Research context** - Explore files, task, repository, documentation:
   * Launch sub-agents (Task tool) to explore codebase, find patterns
   * Search web for external dependencies or unfamiliar concepts
   * Think about requirements, constraints, edge cases
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * For each unknown discovered, add sub-task to investigate

3. **Ask clarifying questions** - Use `AskUserQuestion` for each ambiguity.
   Research and ask until 10/10 understanding.
   * Clarification ≠ approval—do not jump to implementation

4. **Update project doc** - If working on a planned task, update with new context:
   * Organize requirements into MoSCoW priorities (Must/Should/Could/Won't Have)
   * Number requirements (R1, R2, R1.1) for Tasks traceability

5. **STOP** - Tell user to use `/go` when ready to proceed with implementation.
