---
name: ctx-improve
description: Improve context by asking clarifying questions
---

# Improve Context

Use the full understanding checklist and verify our full (10/10) understanding of the task at hand.

Important: any modifications to project or phase docs need to be done via `proj-editing` skill.

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. 🔳 Check current understanding
   - If 10/10 understanding, tell me and stop here
   - Otherwise, tell me your current understanding on a 10 scale

2. 🔳 Research context
   - Launch sub-agents (Task tool) to explore codebase, find patterns
   - Search web for external dependencies or unfamiliar concepts
   - Think about requirements, constraints, edge cases
   - Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   - Speak your mind LOUDLY - don't just use a thinking block, tell me everything you have in mind
   - For each unknown discovered, add sub-task to investigate

3. 🔳 Ask clarifying questions
   - Use `AskUserQuestion` for each ambiguity
   - Research and ask until 10/10 understanding
   - Clarification is not approval - do not jump to implementation

4. 🔳 Update project doc
   - If working on a planned task, update with new context
   - Add/update requirements as R-numbered items (R1, R2, R1.1) for task traceability
   - Requirements describe behavior (WHAT), not implementation (HOW)

5. Report 10/10 understanding achieved. User decides next action (may run /implement, /ctx-plan, or give direction).
