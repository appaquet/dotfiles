{
  nixantic.sources.review-workflow.commands."review-launch" =
    { scope }:
    let
      reviewCheckpoint = scope.forSetting "versionControl.mode" {
        jj = ''
          1. Prepare a dedicated `jj` review change named `private: agent: review - <topic>` using the repository version-control rule
             - Keep reviewer follow-up isolated from unrelated edits
        '';
        git = ''
          1. Prepare an isolated Git review checkpoint using the repository version-control rule
             - Start from a clean or review-only working tree before launching reviewers
             - Reserve `private: agent: review - <topic>` as the commit message for any review-driven follow-up edits
        '';
      };
    in
    {
      description = "Launch review agents for code style, architecture and correctness.";

      effort = "high";

      content = ''
        Goal: launches 4 specialized review agents in parallel to review code changes

        They have all of the necessary instructions internally to figure out what to review, don't instruct
        them on otherwise since you may bias them, unless the user explicitly asks you to review something
        specific.

        The parent agent should launch the agent with NO EXTRA PROMPT since agents already have all the
        context loading capabilities

        ## Instructions

        ${reviewCheckpoint}

        2. Launch 4 specialized agents in BACKGROUND PARALLEL:
           - Agent 1: launch the "code-style-reviewer" agent
           - Agent 2: launch the "code-correctness-reviewer" agent
           - Agent 3: launch the "architecture-reviewer" agent
           - Agent 4: launch the "requirements-reviewer" agent

           - Again, they already have internal instructions. Don't provide them any extra prompt, unless the user explicitly asks you to (e.g. review something specific).
           - By default, they will compute their own changed file list and use their built-in per-file diff. Do not override that unless the user explicitly asks for something specific.
           - Tell them to process with the review by following their internal instructions to the letter, without biasing them with any extra instructions.

           - Note: If an agent doesn't return any results but has finished, don't assume that it failed and
             just consider it as "no issues found". Don't restart the agents as they consume many tokens.

        3. Collect results from agent summaries (returned directly for foreground agents, or delivered
           automatically for background agents). NEVER call `TaskOutput` or read agent output files.
           If an agent's summary lacks detail, send it a follow-up message to ask specific questions.
           Don't act on review comments — agents insert `// REVIEW:` comments in code directly.
           Summarize findings from agent summaries.
      '';
    };
}
