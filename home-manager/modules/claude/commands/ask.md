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
   * Apply <deep-thinking> procedure

3. 🔳 Provide analysis, opinions, alternatives. Challenge assumptions

4. **STOP**: User will decide next steps
