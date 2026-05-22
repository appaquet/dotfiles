{ scope }:
{
  heading = "Context management and sub-agents delegation";
  content = ''
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

      * **Trust methodology, verify decisions.** If a sub-agent reports having run specific commands
        (e.g., "ran `npm test` → 493 passing"), trust that action — they executed it. But act like a
        senior dev reviewing a junior's PR: critically review design choices, implementation quality,
        and whether the right thing was built. Bare conclusions without methodology ("tests pass")
        are unverifiable — follow up or verify independently.

      * When delegating, instruct sub-agents to report methodology — what commands they executed
        and their results. Outcomes without methodology are claims, not information

      * Assume that I don't have any context about what a sub-agent did and outputted. I don't see that
        output, and you have to give me some context if I need to answer questions about it or make
        decisions

      * Sub-agent should communicate with user through `AskUserQuestion` if they need clarifications

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
      * haiku/lightweight: shallow code exploration and reconnaissance
      * sonnet/normal: straightforward code, code exploration
      * opus/bigbrain: planning, review comments research/planning, complex code exploration or
        debugging, complex code
  '';
}
