{
  nixantic.sources.projects.commands."proj-tidy" =
    { scope }:
    {
      description = "Validate and fix project doc consistency against standard structure";

      effort = "xhigh";

      content = ''
        Goal: validate project doc against the standard structure (per project-doc rules) and fix inconsistencies.

        ## State

        ${scope.blocks."project-files".embed}

        ## Instructions

        1. Ensure ${scope.skills."proj-writing".reference} loaded.

        2. 🔳 Read project & phase docs listed above

        3. 🔳 Validate structure
           - Project doc strictly follow project documentation sections & rules
           - Every phase in project doc has corresponding linked phase doc
           - Cross-references between docs are valid

        4. 🔳 Check requirement consistency
           - Project requirements should strictly follow project requirement rules
           - Phase requirements should strictly follow phase requirement rules

        5. 🔳 Check completable items
           - Flag tasks that are done but not marked ✅
           - Flag phases where all tasks `[x]` but phase still 🔄
           - Flag requirements where linked work done but still 🔄
           - Use `AskUserQuestion` before marking ✅

        6. 🔳 Triage Inbox items (if section exists)
           - For each item, propose to user: convert to requirement, add as phase task, move to Questions, or discard. Delete after.
           - Use `AskUserQuestion` to confirm any triage decisions

        7. 🔳 Present findings
           - Group issues by category
           - Show current state and proposed fix for each

        8. ${scope.blocks."engagement-gate".gate}
      '';
    };
}
