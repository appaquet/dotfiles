---
name: Forked
description: Fork a skill's work to sub-agents for parallel execution
arguments:
  - name: skill
    description: The skill to fork (e.g., implement, review-plan)
    required: true
---

# Forked

Goal is to load a given skill, extract its instructions and delegate work to sub-agents

Main agent will handle task decomposition, launching sub-agents, update project docs, and `jj`
operations as per skill requirements.

## Instructions

1. 🔳 Make sure the task at hand is clear. If not, use `AskUserQuestion` to clarify

2. 🔳 Load the skill `$0`
   - Extract its instructions and tasks
   - Think about how to best decompose the work into independent sub-tasks by agents
   - Should not be too granular to avoid overhead, but not too broad to cause conflicts

3. 🔳 For each agent to be launched, create tasks:
   - Launch agent to do X
   - Analyse results
   - Update project docs if applicable

4. If the skill requires to create a `jj` change, make sure to create one before launching
   sub-agents.

5. 🔳 Launch sub-agents in sequence OR parallel, depending on task dependencies.
   - Give as much details as possible on the context, what needs to be implemented, which project
     docs to load, which section of the plan to follow, and any other relevant information.
   - Very thoroughly instruct the sub-agent to create tasks from the skill $0 instructions using the
     🔳 notation and execute them in the exact same way as the original skill would. These should
     exclude any of the parent agent's responsibilities (jj operations, project doc updates, etc.)
   - Instruct the sub-agent to a complete debrief in one single last message:
     - What was done
     - Changed files
     - Results (tests passing, etc.)
     - Next steps or blockers
   - Your context window is very precious.
     You should not attempt to validate their work by running tests, build, format, etc.
     You should not diff any code either, other than listing changed files. 
     Use sub-agents to do any extra work, using same instructions as above.

6. 🔳 Collect debriefs, analyse results, update project docs if applicable. Handle `jj` operations
   as per skill and development instructions requirements.
