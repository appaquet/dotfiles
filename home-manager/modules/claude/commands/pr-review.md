---
name: pr-review
description: Review changes in the current branch / PR for code style, architecture and correctness.
---

# PR Review

1. Load the context of the project and pull request / current branch

2. Create a new jj change for the review

3. Launch 3 specialized agents in **parallel**:
    * Agent 1: launch the "code-style-reviewer" agent
    * Agent 2: launch the "code-correctness-reviewer" agent  
    * Agent 3: launch the "architecture-reviewer" agent

   Note: If an agent doesn't return any results but has finished, don't assume that it failed and
   just consider it as "no issues found". Don't restart the agents as they consume many tokens.

4. Don't act on review comments. Agents should have added comments in the code where the issues are
   found, so you can just read the code and see the comments. You can also read the summary of each
   agent to see what they found and make a summary.
