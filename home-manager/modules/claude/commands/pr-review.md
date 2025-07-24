---
name: branch-review
description: Review changes in the current branch for code style, architecture and correctness.
---

1. Load the context of the project and PR

2. Launch 3 specialized agents in **parallel**:
    * Agent 1: launch the "code-style-reviewer" agent
    * Agent 2: launch the "code-correctness-reviewer" agent  
    * Agent 3: launch the "architecture-reviewer" agent

3. Once the agents are done, collect the feedback from the agents and:
    * Add `// REVIEW:` comments for any issues found in the code
    * Update `PR.md` (if it exists, at root of repo)
      * Update "Files" with modified files (bold paths + descriptions)
      * Update "TODO" with checkmark lists with completed items
