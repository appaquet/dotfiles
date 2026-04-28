# General

* Name: AP
* Environment:
  * OS: NixOS + MacOS (home manager, nix darwin)
  * Shell: fish

## Top-level instructions

* Optimize for future-proofing, not minimal diff. Half-measures cost more total effort

* Freeform requests aren't shortcuts around workflow thinking. Apply workflow steps even when
  not explicitly invoked

* ALWAYS use `AskUserQuestion` to ask questions
  * Never ask directly in response or finish a message with a list of questions. Always use the tool
  * Don't assume I have all context, always make sure to provide necessary context before asking
    questions AND in questions themselves

* Planning is mandatory for ALL implementations, no matter how trivial. NEVER engage the native
  plan mode `EnterPlanMode`. Refer to workflows for planning instructions. When agreed on a plan,
  ALWAYS follow it and ALWAYS stop & ask if you deviate or the plan fails

* NEVER implement until you receive this exact signal: 🚀 Engage thrusters. Wait for it — don't ask
  via `AskUserQuestion` if you can proceed

## Sub-instructions files

* My workflows: @~/.claude/docs/workflows.md
* Project docs: @~/.claude/docs/project-doc.md
* Version control (jj): @~/.claude/docs/version-control.md
* Development instructions: @~/.claude/docs/development.md
* Code style: @~/.claude/docs/code-style.md
* Reviewing: @~/.claude/docs/review.md

## Context management and agentic workflow

* Main agent should primarily be used for high-level planning, project management, jj (code
  versioning). Main agent context window is VERY VERY precious; Anything requiring reading,
  understanding and exploring code should be delegated to sub-agents. Implementation after planning
  should ALWAYS be done by sub-agents

* Sub agents should ALWAYS used for grunt work to preserve main agent context, no matter the task complexity
  * Optimize prompts for sub-agents, but also ask them to optimize their own output message
    Enough information for crystal clear understanding, but no more than that: context window is
    precious

  * If a sub-agent output is insufficient, send it a follow-up message to re-engage and ask targeted
    follow-up questions. If I ask you a question that a previous sub-agent should have answered,
    resume it instead of answering directly or launching a new one. If I ask for a small change to a
    previous sub-agent's work, continue it instead of creating a new one to do the change

  * When a sub-agent comes back with an output, YOU HAVE TO BE CRITICAL. If it doesn't sound right,
    you can send it a follow-up and ask for more details or clarifications. Avoid checking their
    output code yourself, unless very trivial/small

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
  * haiku: shallow code exploration and reconnaissance
  * sonnet: straightforward code, code exploration
  * opus: planning, review comments research/planning, complex code exploration or debugging,
          complex code

* If you are a sub-agent, and running into issues and unforeseen complications, while running sonnet
  or haiku, STOP and tell the main agent. The main agent should be able to restart work with the
  more capable opus model.

* For any workflow that requires multiple steps, synchronization or communication between agents,
  use a team of agent (`TeamCreate`) instead of individual agents
  When using teams, don't kill agents until we're certain that we're done with them and have
  validated their work. We will resume them if we need to go back to them

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

* Your context is precious, make sure the follow the agentic workflow instructions

* ALWAYS use project & phase docs to plan and track work @~/.claude/docs/project-doc.md using the
  proper project editing skills

## Context understanding

Always ensure 10/10 understanding checklist: explore code + web search + `AskUserQuestion`
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
</full-understanding-checklist>

## Problem Solving

ALWAYS use this methodology to solve problems, issues, and bugs:

<problem-solving-checklist>
1. Understand WHY (trace data flow, logging, changes)
2. Fix root cause, not symptom. Generic solution over specific case and bespoke fixes
3. Ask user before destructive changes
4. Test bugs: verify new test catches issue or update existing test to catch it
5. Document investigation: capture uncertainty, what was tried, what was learned in phase doc Questions & Investigations
   Use a SR&ED documentation style to capture learnings and prevent going in circles
</problem-solving-checklist>

## Deep Thinking

Default operating mode, applied proportionally. You systematically underestimate which tasks need
thought — the cost of pausing is always less than rework.

<deep-thinking>
1. STOP rushing - invest thinking tokens now to save iteration tokens later
2. Re-read all relevant context - don't rely on memory
3. Analyze thoroughly (ultra think, be pedantic)
4. Externalize your thinking - speak your mind LOUDLY, don't just use thinking blocks
5. Think as a fresh agent - what could be misinterpreted? What's ambiguous?
6. Question assumptions - what haven't you verified?
</deep-thinking>

## Destructive Operations

Before deleting files/content: ALWAYS make sure we can restore by any means
Always assume you are not alone working on the same code at same time
ALWAYS preserve unknown code and ask instead of deleting / restoring it
