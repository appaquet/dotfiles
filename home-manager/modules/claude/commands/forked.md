---
name: Forked
description: Fork a skill's work to sub-agents for parallel execution
arguments:
  - name: skill
    description: The skill to fork (e.g., implement, review-plan)
    required: true
---

# Forked

Fork a given skill, extract its instructions and delegate work to sub-agents

Main agent's context is precious, we don't want to waste it with heavy tasks that can be done by
sub-agents

Main agent will still handle:

- Task decomposition based on skill instructions and current context
- Launching sub-agents
- Updating project docs along the way
- `jj` operations as per skill requirements

But everything else will be done by sub-agents launched to handle specific tasks (e.g., research,
implementation, reviews, etc.)

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Make sure the task at hand is clear. If not, use `AskUserQuestion` to clarify

3. 🔳 Load `$0` skill if not already loaded using the `Skill` tool
   - Extract its instructions and tasks
   - Think about how to best decompose the work into independent sub-tasks by agents
   - Should not be too granular to avoid overhead, but not too broad to cause conflicts
   - If skill has multiple phases (e.g., plan + implement), consider launching sub-agents per phase

4. 🔳 For each agent to be launched, create tasks:
   - Launch agent to do X
   - Analyse results
   - Update project docs if applicable

5. If the skill requires to create a `jj` change, make sure to create one before launching
   sub-agents

6. 🔳 Launch sub-agents in sequence OR parallel, depending on task dependencies
   - Give as much details as possible on the context, what needs to be implemented, which project
     docs to load, which section of the plan to follow, and any other relevant information

   - Very thoroughly instruct the sub-agent to create tasks from the skill $0 instructions using the
     🔳 notation and execute them in the exact same way as the original skill would. These should
     exclude any of the parent agent's responsibilities (jj operations, project doc updates, etc.)

   - Instruct the sub-agent to a complete debrief in one single last message:
     - What was done
     - Changed files (detailed to avoid having you to diff to understand)
     - Results (tests passing, etc.)
     - Next steps or blockers

   - Your context window is very precious
     You should NOT attempt to validate their work by running tests, build, format, etc
     You should NOT diff any code either, other than listing changed files to prevent context bloat
     You should NEVER call `TaskOutput` on background agents — it returns full transcripts, not
     summaries. Background agents deliver their summary automatically when done
     You should ALWAYS use sub-agents to do any extra work, using same instructions as above

7. 🔳 Collect debriefs, analyse results and report on overall progress
      If requested by skill, update project docs using the `ctx-save` skill
      Handle `jj` operations as per skill and development instructions requirements
