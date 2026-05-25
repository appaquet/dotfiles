{ scope }:
{
  heading = "Sub-agents workflows";
  content = ''
    Rules for managing our context and maximizing sub-agents delegation to preserve it.
  '';

  tag = "sub-agents-workflows";
  taggedContent = ''
    * Main agent: 
      * Used primarily for high-level orchestration, project management, jj (code versioning). Main
        agent context window is VERY VERY precious; Anything requiring reading, understanding and
        exploring code should be delegated to sub-agents.

    * Sub-agents:
      * Delegation threshold:
        * Trivial, single-location edits with no multi-steps testing (typo, fixture data) → main agent, if have write access
        * Multi-file changes, new logic, iterative test<>code → sub-agent
        * In doubt; delegate

      * Agent selection: select right sub-agent for task. junior/senior/staff have different pricing

      * Grouping: group related work to same sub-agent for more focused and less conflicts, taking
        agent selection rules in account

      * Parallelism: if multiple unrelated tasks, launch multiple sub-agents in parallel, but
        careful about potential file conflicts

      * Prompt to sub-agent: optimize prompts for sub-agents, reference project files and push to
        read instead of copying in prompt to sub-agent. tell them OK to engage (🚀)

      * Sub-agent output: ask to optimize output; enough info for clear understanding and proof of
        correct work; resume if not enough

      * Resuming: If sub-agent output is insufficient, send resume / follow-up message. Ask targeted follow-up
        questions. If I ask you a question that previous sub-agent should have answered, resume it
        instead of answering directly or launching a new one. If I ask for a small change to a
        previous sub-agent's work, resume it instead of creating a new one to do the change

      * Trust work: If it reports having run commands (e.g. "ran tests → 493 passing"), trust
        it. But, act like senior dev reviewing a junior PR: critically review design/choices/quality.
        If not enough: resume.

      * Sub-agent to me: assume I don't have context of sub-agent output. If need communicate to me,
        give context of output of sub-agent since I don't have it. They can communicate with me via
        `AskUserQuestion` if need clarifications

      * Project docs: project doc source of truth (with code). always reference it, don't copy to prompt
        If sub-agent is doing documentation work, OK to write to project docs directly instead of you
  '';
}
