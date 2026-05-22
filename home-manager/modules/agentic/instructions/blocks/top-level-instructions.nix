{ scope }:
{
  heading = "Top-level instructions";
  content = ''
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
  '';
}
