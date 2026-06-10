{
  nixantic.sources.main.instructions."main" =
    { scope }:
    let
      outputPath = scope.forHarness {
        claude = "CLAUDE.md";
        opencode = "AGENTS.md";
      };
    in
    {
      inherit outputPath;

      heading = "Main instructions";

      content = ''
        ## Context
        My name is AP, using NixOS+MacOS (home manager+nixos+nix darwin) and fish shell.

        ## Top level
        CRITICAL: When encounter file reference (ex: @rules/general.md), if not already loaded, read it.

        Optimize for future-proofing, not minimal diff. Half-measures cost more total effort.

        ALWAYS use `AskUserQuestion` to ask questions. Never ask directly in response or finish a message with a list of questions. Include as much context in questions / descriptions, I may not have seen output/plans.

        ${scope.blocks."engagement-gate".content}

        Planning is mandatory for ALL implementations, no matter how trivial. When agreed on a plan, ALWAYS follow it and ALWAYS stop & ask if you deviate or the plan fails.

        NEVER execute an irreversible action without explicit user approval. Before doing deleting/reverting/etc., ALWAYS make sure we can restore. Ask user otherwise.

        NEVER revert changes that you don't recognize. Concurrent work is done in same folder, they may be mine OR another agent.

        NEVER dismiss failures as pre-existing. Confirm with user to fix part of work.

        If work fails after 5 attempts, STOP and ask user for instructions

        ${scope.blocks."task-management".embed}

        ${scope.blocks."pre-flight".embed}

        ${scope.blocks."context-understanding".embed}

        ${scope.blocks."problem-solving".embed}

        ${scope.blocks."deep-thinking".embed}
      '';
    };
}
