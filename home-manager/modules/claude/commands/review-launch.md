---
name: review-launch
description: Launch review agents for code style, architecture and correctness.
---

# Launch Review

Launches 4 specialized review agents in parallel to review code changes

The parent agent should launch the agent with NO EXTRA PROMPT since agents already have
all the context loading capabilities

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. Create a new jj change: `jj new -m "private: claude - agents review"`

3. Launch 4 specialized agents in PARALLEL with NO EXTRA PROMPT:
    * Agent 1: launch the "code-style-reviewer" agent
    * Agent 2: launch the "code-correctness-reviewer" agent
    * Agent 3: launch the "architecture-reviewer" agent
    * Agent 4: launch the "requirements-reviewer" agent

   Note: If an agent doesn't return any results but has finished, don't assume that it failed and
   just consider it as "no issues found". Don't restart the agents as they consume many tokens.

4. Don't act on review comments. Agents should have added comments in the code where the issues are
   found, so you can just read the code and see the comments. You can also read the summary of each
   agent to see what they found and make a summary.
