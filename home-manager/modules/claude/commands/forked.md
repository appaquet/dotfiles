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
sub-agents. Main agent should ONLY be responsible for:

- Task decomposition based on skill instructions and current context
- Launching sub-agents
- Updating project docs along the way
- `jj` operations as per skill requirements

Everything else must be done by sub-agents launched to handle specific tasks (e.g., research,
implementation, reviews, etc.). This applies to ALL tasks: trivial, obvious or not. NEVER make
judgment calls on if something is simple enough to be done by main agent

## Model selection

When launching sub-agents, pick the right model for the task to optimize speed & accuracy:

- haiku: shallow code exploration, straightforward code
- sonnet: normal code, complex code exploration, most tasks
- opus: planning, complex code

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Make sure the task at hand is clear. If not, use `AskUserQuestion` to clarify

3. 🔳 Load `$0` skill if not already loaded using the `Skill` tool
   - Extract its instructions and tasks
   - Think about how to best decompose the work into independent sub-tasks by agents
   - Should not be too granular to avoid overhead, but not too broad to cause conflicts
   - If skill has multiple phases (ex: plan + implement), consider launching sub-agents per phase
   - If an agent require user intervention (ex: manual test, validation), inform agent to stop its
     work, parent agent handle communication and then relaunch agent with new information
   - Agent can stop early and you can use resume if more complex interaction needed

4. 🔳 For each agent to be launched, create tasks:
   - Launch agent to do X
   - Analyse results
   - Update project docs if applicable using `/ctx-save` procedure (on main agent)

5. If the skill requires to create a `jj` change, make sure to create one before launching
   sub-agents

6. 🔳 Launch sub-agents in sequence OR parallel, depending on task dependencies
   - Give as much details as possible on the context, what needs to be implemented, which project
     docs to load, which section of the plan to follow, and any other relevant information

   - Instruct the sub-agent to load the forked skill (`$0`) via the `Skill` tool, create tasks from
     its 🔳 steps, and follow its full process (checklists, validation). Tell the sub-agent that it
     should NEVER do the steps that are parent-only responsibilities (listed above, jj/docs/etc.).
     You need to explicitly tell the sub-agent to IGNORE instructions from the skill that are about

   - Optimize sub-agent prompts and output — enough for parent to understand and decide next steps,
     not exhaustive dumps:
     - State the specific question or deliverable, not open-ended exploration
     - Specify expected output format (e.g., "2-3 sentences", "findings with
       reasoning", "file list with one-line descriptions")
     - Instruct sub-agent to debrief concisely in one final message
       (target: ~500 tokens research, ~1000 implementation):
       - Lead with actionable findings, not the process
       - Changed files with one-line description each
       - Results (pass/fail) and next steps or blockers

   - Your context window is very precious
     - NEVER do any validation or verification yourself
       No tests, builds, browser snapshots, code inspection or any other form of checking
       Route ALL verification to a sub-agent
     - You should NOT diff any code either, other than listing changed files to prevent context bloat
     - NEVER call `TaskOutput` or read agent output files — they contain raw transcripts, not
       summaries. Foreground agents return results in the tool response. Background agents deliver
       summaries automatically
     - If an agent's debrief is insufficient, use the `resume` parameter (with the agent's ID from
       the Task tool result) to re-engage it and ask targeted follow-up questions
     - ALWAYS use sub-agents for any work beyond parent-only responsibilities (listed at the top
       of this file)
     - Think about that when instructing the agent: optimize their output for your context and
       preventing you from having to do extra work to validate or understand it

7. 🔳 Collect debriefs, analyse results and report on overall progress
      If a debrief lacks needed detail, resume the agent (Task tool `resume` parameter with agent ID)
      to ask specific follow-up questions rather than reading raw transcripts
      Make sure progress reflected in project docs as per instructions in the skill using `/ctx-save` procedure
      Handle `jj` operations as per skill and development instructions requirements
