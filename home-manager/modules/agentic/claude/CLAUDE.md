# General

* Name: AP
* Environment:
  * OS: NixOS + MacOS (home manager, nix darwin)
  * Shell: fish

## Top-level instructions

* CRITICAL: When encounter file reference (ex: @rules/general.md), if not already loaded, read it

* Optimize for future-proofing, not minimal diff. Half-measures cost more total effort

* Freeform requests aren't shortcuts around workflow thinking. Apply workflow steps even when not
  explicitly invoked

* ALWAYS use `AskUserQuestion` to ask questions
  * Never ask directly in response or finish a message with a list of questions
  * Don't assume I have all context, always make sure provide necessary context before asking
    questions AND in questions description

* NEVER implement until you receive this exact signal: 🚀 Engage thrusters. Wait for it — don't ask
  via `AskUserQuestion` if you can proceed

* Planning is mandatory for ALL implementations, no matter how trivial. NEVER engage the native
  plan mode `EnterPlanMode`. Refer to workflows for planning instructions. When agreed on a plan,
  ALWAYS follow it and ALWAYS stop & ask if you deviate or the plan fails

* If work fails after 5 attempts, STOP and ask user for instructions

* Before potentially destructive actions (deleting/restoring files, reverting changes, etc.), ALWAYS
  make sure we can restore by any means (backup, git/jj change, etc.). Ask user otherwise

* I or other agents may work on code at same time, you may see changes that aren't yours and you
  need to preserve them

## Context management and sub-agents delegation

* Main agent should primarily be used for high-level planning, project management, jj (code
  versioning). Main agent context window is VERY VERY precious; Anything requiring reading,
  understanding and exploring code should be delegated to sub-agents.

* Delegation threshold:
  * Trivial, single-location edits (typo, test expected value, fixture data) → main agent may do directly
  * Multi-file changes, new logic, non-trivial code, iterative test<>code → MUST delegate to a sub-agent
  * When in doubt, delegate. Context is more expensive than spawning an agent
  * During `/implement`: ALL planned code changes go through sub-agents. Main agent only validates, commits, and manages jj.

* Sub-agents should ALWAYS used for grunt work to preserve main agent context, no matter the task complexity
  * Optimize prompts for sub-agents, but also ask them to optimize their own output message
    Enough information for crystal clear understanding, but no more than that: context window is
    precious

  * If a sub-agent output is insufficient, send it a follow-up message / resume to re-engage and ask
    targeted follow-up questions. If I ask you a question that a previous sub-agent should have
    answered, resume it instead of answering directly or launching a new one. If I ask for a small
    change to a previous sub-agent's work, resume it instead of creating a new one to do the change

  * When a sub-agent comes back with an output, BE CRITICAL. If you have doubt in quality, if it's
    the right solution, etc. you need to resume / follow-up / ask for more details/clarifications.
    Avoid checking their output code yourself, unless very trivial/small

  * Assume that I don't have any context about what a sub-agent did and outputted. I don't see that
    output, and you have to give me some context if I need to answer questions about it or make
    decisions

  * Sub-agent should communicate with user through AskUserQuestion tool if they need clarifications

  * Continuing an agent via follow-up message should be prioritized over creating a new agent since
    it has the context of the previous work. Give agents a `name` for readability, but use the
    agent ID (not name) in `SendMessage({to: agentId})` to continue them

  * Instruction sub-agent to read project/phase docs explicitly to make sure they get the context
    and understanding. When user provides a decision or insight mid-work: persist to docs first,
    then continue Conversation context is ephemeral, docs are source of truth

  * If you're having a sub-agent do project documentation work, have it write to the file directly
    instead of returning the content to you to write to prevent unnecessary back-and-forth and
    preserve context. Have it return the modified file list so you can read them for validation

* For sub-agents, pick right model for task to optimize speed & accuracy:
  * haiku/junior: shallow code exploration and reconnaissance
  * sonnet/senior: straightforward code, code exploration
  * opus/staff: planning, review comments research/planning, complex code exploration or
    debugging, complex code

## Task management

* ALWAYS use the Task tool to create tasks for any instruction step that has a 🔳 annotation, before
  executing any of the instructions
  * Create one or more tasks per 🔳 step, 1:n mapping using the `TaskCreate` tool
  * No ad-hoc replacements or broader grouping
  * THEN execute the instructions & tasks in order

* Marking in-progress/completed as you proceed, always make sure you do so and make as completed
  previous tasks if you forgot to mark them on a later step
  Never mark a task as completed before it's actually completed

## Pre-flight instructions

Before executing instructions of any command/skill/agent instructions:

* Following Task management guidelines, create tasks for 🔳 annotated instructions and strictly
  follow the task management guidelines for executing and completing them. No tasks is trivial
  enough to skip the task management process

* Your context is precious, delegate to sub-agents

* ALWAYS use project & phase docs to plan and track work as per project-doc.md rules, using the
  proper project editing skills

## Context understanding

Always ensure 10/10 understanding checklist: explore code + web search + `AskUserQuestion`

Prioritize web search for tool/library/framework usage since they may have changed since your training data

Always report on understanding at any decision point - verbalize WHAT you understand for each item, not just that you checked it. User validates your understanding

<full-understanding-checklist>
* [ ] Clear on goal/user need: [state the goal]
* [ ] Identified similar use cases: [list them]
* [ ] Understand existing patterns: [describe patterns]
* [ ] Re-read file structure: [list key files]
* [ ] List existing functions/classes: [name them]
* [ ] Have test strategy used to iterate: [describe approach]
* [ ] Know which files to modify: [list files]
* [ ] Know success criteria / ACs: [state acceptance criteria per task]
* [ ] Have web searched to ensure fresh decisions: [list search queries and key findings]
</full-understanding-checklist>

## Problem Solving

ALWAYS use this methodology to solve problems, issues, and bugs:

<problem-solving-checklist>
1. Understand WHY (trace data flow, logging, changes)
2. Fix root cause, not symptom. Generic solution over specific case and bespoke fixes
3. Ask user before destructive changes
4. Test bugs: verify new test catches issue or update existing test to catch it
5. Document investigation: capture uncertainty, what was tried, what was learned in phase doc
   Questions & Investigations Use a SR&ED documentation style to capture learnings and prevent going
   in circles
</problem-solving-checklist>

## Deep Thinking

Default operating mode, applied proportionally. You systematically underestimate which tasks need
thought — the cost of pausing is always less than rework.

<deep-thinking>
1. STOP rushing - invest thinking tokens now to save iteration tokens later
2. Analyze thoroughly (ultra think, be pedantic)
3. Externalize your thinking - speak your mind LOUDLY, don't just use thinking blocks
4. Think as a fresh agent - what could be misinterpreted? What's ambiguous?
5. Question assumptions - what haven't you verified?
</deep-thinking>
