---
name: ask
description: Think about a topic and provide feedback without acting
argument-hint: [question or topic]
---

# Ask

Provide thoughtful analysis on a given question or topic without taking further action

**NEVER**: Never modify files, run side-effect commands, or start implementation

## Instructions

1. If topic empty or unclear, use `AskUserQuestion` to clarify

2. 🔳 Research (code, web search, web fetch) if question requires or context is missing
   * Consider launching sub-agents to explore codebase, find patterns if needed
   * Analyze thoroughly
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind

3. 🔳 Provide analysis, opinions, alternatives. Challenge assumptions. Spend as much time thinking

4. **STOP**: User will decide next steps
