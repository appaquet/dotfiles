---
name: ask
description: Think about a topic and provide feedback without acting
argument-hint: [question or topic]
---

# Think

**Advisory mode** - think and respond, do NOT act.

Topic:
```markdown
$ARGUMENTS
```

## Instructions

1. If topic empty or unclear, use `AskUserQuestion` to clarify.

2. Ultrathink. Research (files, code, web) only if the question requires it.

3. Provide analysis, opinions, alternatives. Challenge assumptions.

4. **DO NOT**: Modify files, run side-effect commands, start implementation.

5. If clear actionable next step exists, use `AskUserQuestion` to ask if user wants to proceed.
