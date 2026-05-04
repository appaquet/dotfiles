---
name: review-launch
description: Launch review agents for code style, architecture and correctness.
effort: high
---

# Launch Review

Launches 4 specialized review agents in parallel to review code changes

The parent agent should launch the agent with NO EXTRA PROMPT since agents already have all the
context loading capabilities. The only circumstance where you should provide an extra prompt is if I
explicitly ask you to review something specific (ex: from a specific jj change, whole repo, etc.)

## Instructions

1. Pre-flight then continue

2. Create a new jj change: `jj new -m "private: claude: agents review"`

3. Launch 4 specialized agents in BACKGROUND PARALLEL with **NO EXTRA PROMPT**:
    * Agent 1: launch the "code-style-reviewer" agent
    * Agent 2: launch the "code-correctness-reviewer" agent
    * Agent 3: launch the "architecture-reviewer" agent
    * Agent 4: launch the "requirements-reviewer" agent

   You should not provide them any extra prompt. They are designed to load all necessary context and
   information on their own and inject review comments directly in the code. Leave the extra prompt
   / prompt parameter empty, unless I explicitly ask extra prompt. Don't follow the tool
   instructions to provide an extra prompt, do what I just said here.

   Agents instructions should already be clear on what to review, unless I explicitly ask something
   else. Don't provide any prompt, just launch them with no prompts.

   Note: If an agent doesn't return any results but has finished, don't assume that it failed and
   just consider it as "no issues found". Don't restart the agents as they consume many tokens.

4. Collect results from agent summaries (returned directly for foreground agents, or delivered
   automatically for background agents). NEVER call `TaskOutput` or read agent output files.
   If an agent's summary lacks detail, send it a follow-up message to ask specific questions.
   Don't act on review comments — agents insert `// REVIEW:` comments in code directly.
   Summarize findings from agent summaries.
