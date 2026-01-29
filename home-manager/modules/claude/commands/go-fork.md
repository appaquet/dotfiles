---
name: Go Fork
description: Proceed to implementation of the plan or task at hand in a forked context
context: fork
---

# Go Fork

Invoke the `/go` command using the `Skill` tool (e.g., `skill: "go"`), then report on the outcome.

**Important**: You must literally call the Skill tool to invoke `/go` - do NOT implement the plan
directly. The `/go` command handles task tracking, understanding verification, and proper workflow.

After `/go` completes, debrief thoroughly:
* What was done
* Changed files
* Results (tests passing, etc.)
* Next steps or blockers
