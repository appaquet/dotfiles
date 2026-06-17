{
  nixantic.sources.orchestration.blocks."sub-agents-workflows" =
    { scope }:
    {
      content = ''
        Rules for managing our context and maximizing sub-agents delegation to preserve it.
      '';

      preFlightRecall = "Your context precious, use <sub-agent-workflows> instructions. Always
      prefer deletion to preserve context.";

      tag = "sub-agents-workflows";
      taggedContent = ''
        * Main agent: Used primarily for high-level orchestration, project management, version control. Main agent context window is VERY precious; Anything requiring reading, understanding and exploring code should be delegated to sub-agents.

        * Sub-agents
          * Delegation threshold:
            * Project document work
              * No matter the size, always main agent
            * Writing code
              * Orchestrator mode (no write access) -> delegate
              * Trivial, single-location edits with no multi-steps testing (typo, fixture data) → main agent
              * Multi-files changes, new logic, iterative test<>code → delegate
            * Reading code
              * bounded 1-2 files → main agent
              * unbounded reading, exploration → delegate
            * In doubt -> delegate

          * Agent selection: select right sub-agent for task, each have different pricing and need to optimize for it. Avoid using explore/general/plan agents, select proper dev agent instead. Prioritize using more senior implementation agents for high level planning, use principal-dev only for top-tier insights/advisory escalation, then more junior executing that plan.
            * junior-dev: ${scope.agents."junior-dev".description}
            * senior-dev: ${scope.agents."senior-dev".description}
            * staff-dev: ${scope.agents."staff-dev".description}
            * principal-dev: ${scope.agents."principal-dev".description}

          * Grouping: group related work to same sub-agent for more focused and less conflicts, but careful of selection.

          * Parallelism: if multiple unrelated tasks, launch multiple sub-agents in parallel, but careful about potential file conflicts.

          * Prompt to sub-agent: optimize prompts for sub-agents, reference project files and push to read instead of copying in prompt to sub-agent.

          * Sub-sub-agents: sub-agents can launch other sub-agents for review/insights/explore. When calling more senior, senior shouldn't do the work, but only give plan/insights. Calling more junior can be done to help manage context on grunt work. Follow agent selection rule. Never delegate to the same level agent work, you can do it.

          * Sub-agent output: ask to optimize output; enough info for clear understanding and proof of correct work; resume if not enough.

          * Resuming: If sub-agent output is insufficient, send resume / follow-up message. Ask targeted follow-up questions. If I ask you a question that previous sub-agent should have answered, resume it instead of answering directly or launching a new one. 

          * Reuse: If I ask for a small change to a previous sub-agent's work, resume it instead of creating a new one to do the change. For new tasks, use new sub-agents to prevent blowing up context, even if it's related, to prevent context blowup and focus.

          * Trust work: If it reports having run commands (e.g. "ran tests → 493 passing"), trust it. But, act like senior dev reviewing a junior PR: critically review design/choices/quality. If not enough: resume. Don't re-analyze work that a sub-agent did. if it's not enough, ask it to do more. you shouldn't start reading files that a sub-agent worked on to make your own idea, it's the sub-agent's job

          * Sub-agent to me: assume I don't have context of sub-agent output. If need communicate to me, give context of output of sub-agent since I don't have it. They can communicate with me via `AskUserQuestion` if need clarifications

          * Project docs: project doc source of truth (with code). always reference it, don't copy to prompt If sub-agent is doing documentation work, OK to write to project docs directly instead of you
      '';
    };
}
