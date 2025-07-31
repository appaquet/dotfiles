---
name: branch-review
description: Review changes in the current branch / PR for code style, architecture and correctness.
---

1. Load the context of the project and PR

2. Create a new jj change for the review

3. Launch 3 specialized agents in **parallel**:
    * Agent 1: launch the "code-style-reviewer" agent
    * Agent 2: launch the "code-correctness-reviewer" agent  
    * Agent 3: launch the "architecture-reviewer" agent

   Note: If an agent doesn't return any results but has finished, don't assume that it failed and
   just consider it as "no issues found". Don't restart the agents as they consume many tokens.

4. Once the agents are done, collect the feedback from the agents and:
    * Add any missing `// REVIEW: <agent name> - <comment>` for issues raised by agents
    * Update `PR.md` (if it exists, at root of repo)
      * Update "Files" with modified files (bold paths + descriptions)
      * Update "TODO" with checkmark lists with completed items
