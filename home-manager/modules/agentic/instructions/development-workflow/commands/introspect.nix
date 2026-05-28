{
  nixantic.sources.development-workflow.commands."introspect" =
    { scope }:
    {
      description = "Reflect on an error or undesired behavior to propose instruction improvements";

      argumentHint = "[description of issue]";

      effort = "xhigh";
      content = ''
        Goal: reflect on what went wrong and propose instruction changes to prevent recurrence.

        Issue: `$ARGUMENTS`

        ## Instructions

        1. If issue empty, use `AskUserQuestion` to get description

        2. 🔳 Analyze the issue:
           * Use the ${scope.blocks.deep-thinking.reference} procedure
           * What specific error/behavior occurred?
           * Trace back: what instruction was missing, unclear, or conflicting?
           * Which files might have related concepts? Search for them
           * We don't want specific fixes/root cause, we want to identify the generic underlying issue that
             caused this and how to prevent it in the future

        3. 🔳 Summarize findings:
           * Root cause
           * Files that need changes (including files with related concepts)
           * Conceptual changes needed
           * Need to be generic, not specific to this case

        **STOP** - Do not implement changes directly. User will use `/mem-edit` to do it.
      '';
    };
}
