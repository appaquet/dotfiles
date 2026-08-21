{
  # Dev-agent routing dimensions. Keep rendered descriptions below short and aligned with these boundaries.
  # - Junior
  #   - Exploration: Main agent for code exploration and factual lookup.
  #   - Implementation and decisions: Deterministic, low-risk mechanical details only; no behavior, scope, design, requirement, plan, or prose-meaning decisions.
  #   - Diagnosis: None.
  #   - Version control: Read-only inspection only; no write operations or conflict resolution.
  #   - Risk and ownership: Low risk; return any required judgment or diagnosis.
  # - Mid
  #   - Exploration: Inseparable from Mid-level implementation.
  #   - Implementation and decisions: Established-pattern implementation and test iteration within settled requirements/architecture.
  #   - Diagnosis: Reproducible failures.
  #   - Risk and ownership: Return design/tradeoff, difficult/ambiguous diagnosis, or critical/high-blast-radius decisions.
  # - Senior
  #   - Exploration: Inseparable from subsystem or ambiguous work.
  #   - Implementation and decisions: Complex implementation, subsystem/interface design, and cross-component tradeoffs within established system architecture.
  #   - Diagnosis: Difficult or ambiguous failures regardless of component count.
  #   - Risk and ownership: Return cross-system architecture, systemic diagnosis, critical/high-blast-radius decisions, or product direction.
  # - Staff
  #   - Exploration: Cross-system investigation.
  #   - Implementation and decisions: Cross-system architecture/implementation and technical decisions within supplied product direction.
  #   - Diagnosis: Systemic failures.
  #   - Risk and ownership: Own critical/high-blast-radius technical work; return product direction or user-requested advisory review.
  # - Principal
  #   - Exploration: User-requested review only.
  #   - Implementation and decisions: Options, risks, evidence, and recommendations; no execution decisions or ownership.
  #   - Diagnosis: Debugging direction and strategic diagnosis.
  #   - Risk and ownership: Explicit-user-invoked and advisory-only; parent determines execution.
  nixantic.sources.orchestration.instructions."orchestration" =
    { scope }:
    {
      role = "rule";
      heading = "Sub-agents workflows";
      content = ''
        ${scope.blocks."sub-agents-workflows".embed}
      '';
    };

  nixantic.sources.orchestration.blocks."sub-agent-selection" =
    { scope }:
    {
      content = "Rules for selecting a dev sub-agent.";

      tag = "sub-agent-selection";
      taggedContent = ''
        * Agent selection: select the listed dev agent whose description fits the task. Do not substitute explore/general/plan agents.
          * explore: Local code exploration, web search/explore, but not to be used for debugging / decision-making
          * junior-dev: ${scope.agents."junior-dev".description}
          * mid-dev: ${scope.agents."mid-dev".description}
          * senior-dev: ${scope.agents."senior-dev".description}
          * staff-dev: ${scope.agents."staff-dev".description}
          * principal-dev: ${scope.agents."principal-dev".description}
      '';
    };

  nixantic.sources.orchestration.blocks."sub-agents-workflows" =
    { scope }:
    {
      content = ''
        Rules for managing our context and maximizing sub-agents delegation to preserve it.
      '';

      preFlightRecall = "Your context precious, use <sub-agents-workflows> instructions.";

      tag = "sub-agents-workflows";
      taggedContent = ''
        * Main agent: 
          * Used primarily for high-level orchestration, project management, version control, decision orchestrator. 
          * Main agent context window is VERY precious; Anything requiring exploring/reading code should be delegated to sub-agents. 
          * It is CRITICAL for the main agent to understand the project, key decisions, design, architecture, etc. to properly orchestrate sub-agents.

        ${scope.blocks."sub-agent-selection".embed}

        * Sub-agents
          * Delegation threshold:
            * Project document read/work
              * No matter the size, always main agent
            * Writing code
              * Orchestrator mode (no write access) -> delegate
              * Trivial, single-location edits with no multi-steps testing (typo, fixture data) → main agent
              * Multi-files changes, new logic, iterative test<>code → delegate
            * Reading code
              * bounded 1-2 files → main agent
              * unbounded reading, exploration → delegate
            * Web search
              * Always on sub-agent as results can be long and require analysis
            * In doubt -> delegate

          * Grouping: group related work to same sub-agent for more focused and less conflicts, but careful of selection.

          * Parallelism: if multiple unrelated tasks, launch multiple sub-agents in parallel, but careful about potential file conflicts.

          * Prompt to sub-agent:
            * Reference relevant project/phase files; push to read them rather than copying their content.
            * State the workspace directory and that they are a sub-agent.
            * Do not pre-chew investigation or judgment for sub-agents that can do it themselves.

          * Sub-agent output: ask to optimize output; enough info for clear understanding and proof of correct work; resume if not enough.

          * Resuming: If a sub-agent's delegated work is incomplete, its output needs clarification, or a follow-up directly continues that work, resume it with targeted instructions.

          * Reuse: Reuse sub-agents only within the same user request; use new sub-agents for each subsequent request, even when related to previous work.

          * Sub-agent work trusting:
            * Accept concrete reported facts, such as commands run and test results.
            * Act as tech lead: critically assess design, choices, scope, quality, and evidence.
            * If insufficient, resume the sub-agent with targeted questions or work; don't redo its work.

          * Project files: always reference relevant project files rather than copying their contents into sub-agent prompts. Project and phase documentation remain main-agent-owned. Other documentation may be delegated according to agent descriptions.
      '';

      /*
          * Sub-sub-agents:
            * Use specialist review/exploration agents only for work within the delegating dev agent's stated task and decision limits.
            * Return work exceeding those limits to the parent instead of delegating it to another dev agent.
            * Delegate lower-tier work only when separable, deterministic, independently verifiable, and worth the handoff.
            * Never delegate to the same tier.
      */
    };
}
