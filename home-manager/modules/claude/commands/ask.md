---
name: ask
description: Think about a topic and provide feedback without acting
argument-hint: [question or topic]
---

# Ask

**Advisory mode** - think and respond, do NOT act.

Topic: $ARGUMENTS

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. If topic empty or unclear, use `AskUserQuestion` to clarify.

2. Research (files, code, web) only if the question requires it.
   * Consider launching sub-agents to explore codebase, find patterns if needed.
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.

3. Provide analysis, opinions, alternatives. Challenge assumptions. You need to think deeply here.

4. **DO NOT**: Modify files, run side-effect commands, start implementation.

5. If clear actionable next step exists, use `AskUserQuestion` to ask if user wants to proceed.
