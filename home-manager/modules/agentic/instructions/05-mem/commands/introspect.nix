{
  nixantic.sources.development-workflow.commands."introspect" =
    { scope }:
    {
      description = "Reflect on an error or undesired behavior to propose instruction improvements and apply them on approval";

      arguments = [
        {
          label = "Issue";
          hint = "[description of issue]";
        }
      ];

      effort = "xhigh";
      content = ''
        Goal: reflect on what went wrong, propose generic instruction changes to prevent recurrence, and apply them on approval.

        ## Instructions

        1. 🔳 Load `${scope.skills."mem-writing".name}` skill

        2. If issue empty, ${scope.harness.prose.questions.request} to get description

        3. 🔳 Analyze the issue per ${scope.skills."mem-writing".reference} guidelines:
           * What specific error/behavior occurred?
           * Trace back: what instruction was missing, unclear, or conflicting?
           * Which files might have related concepts? Search for them
           * We don't want specific fixes/root cause, we want to identify the generic underlying issue that
             caused this and how to prevent it in the future

        4. 🔳 Summarize findings:
           * Root cause
           * Files that need changes (including files with related concepts)
           * Conceptual changes needed
           * Need to be generic, not specific to this case

        5. 🔳 Present the findings and ${scope.harness.prose.questions.request} to confirm whether to apply the proposed changes
           * On approval: apply them per ${
             scope.skills."mem-writing".reference
           } guidelines: edit authoritative sources, regenerate
             with the repository's check and build commands, and review the full generated diff
           * On denial: stop with the summary
      '';
    };
}
