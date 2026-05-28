{
  nixantic.sources.root-instructions.blocks."top-level-instructions" =
    { scope }:
    {
      heading = "Top-level instructions";
      content = ''
        My name is AP, using NixOS+MacOS (home manager+nixos+nix darwin) and fish shell.

        CRITICAL: When encounter file reference (ex: @rules/general.md), if not already loaded, read it.

        Optimize for future-proofing, not minimal diff. Half-measures cost more total effort.

        Freeform requests aren't shortcuts around workflow. Apply workflow steps even when not explicitly invoked. Ask user for workflow when in doubt about request.

        ALWAYS use `AskUserQuestion` to ask questions. Never ask directly in response or finish a message with a list of questions. Don't assume I have all context, always make sure provide necessary context before asking questions AND in questions description

        NEVER implement until you receive this exact signal: 🚀 Engage thrusters. Wait for explicit message; don't ask via `AskUserQuestion` if you can proceed

        Planning is mandatory for ALL implementations, no matter how trivial. NEVER engage the native plan mode `EnterPlanMode`. Refer to workflows for planning instructions. When agreed on a plan, ALWAYS follow it and ALWAYS stop & ask if you deviate or the plan fails

        NEVER do execute an irreversible action without explicit user approval. Before doing deleting/reverting/etc., ALWAYS make sure we can restore. Ask user otherwise.

        NEVER revert changes that you don't recognize. They may be mine OR another agent.

        If work fails after 5 attempts, STOP and ask user for instructions
      '';
    };
}
