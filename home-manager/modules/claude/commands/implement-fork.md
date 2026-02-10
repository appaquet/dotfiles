---
name: Forked Implement
description: Proceed to implementation of the plan in a forked context
---

# Forked Implement

Our goal is to launch a sub-agent to implement the plan or task at hand in a forked context.

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

Give it as much context as possible about what needs to be implemented, which project documents to
load, which section of the plan to follow, and any other relevant information. It should update the
code base and project documentation as needed.

Once launched, it should use the `/implement` command to carry out the implementation in the forked
context. You should NEVER tell the agent to skip `/implement` because the task is easy.

Do not reinstruction the sub-agent with the steps from `/implement` (see
@~/.claude/commands/implement.md). You can add new instructions, but they should not duplicate what
is already in `/implement`.

After `/implement` completes, instruct the agent to debrief thoroughly:

- What was done
- Changed files
- Results (tests passing, etc.)
- Next steps or blockers

NEVER call `TaskOutput` or read agent output files — they return raw transcripts, not summaries.
Agent results come via tool response (foreground) or automatic delivery (background).
