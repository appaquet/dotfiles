{
  nixantic.sources.projects.commands."proj-tidy" = {
    description = "Validate and fix project doc consistency against standard structure";

    effort = "xhigh";

    content = ''
      Goal: validate project doc against the standard structure (per project-doc rules) and fix inconsistencies.

      Current project files: !`claude-proj-docs`

      ## Instructions

      1. Ensure `proj-editing` skill loaded.

      2. 🔳 Read project & phases docs

      3. 🔳 Validate structure
         - Project doc strictly follow project documentation sections & rules
         - Every phase in project doc has corresponding linked phase doc
         - Cross-references between docs are valid

      4. 🔳 Check requirement consistency
         - Flag overlapping requirements as potential conflicts
         - Phase doc requirements must derive from parent R-numbers
         - Project doc references phase doc when phase expands requirements
         - Tasks without AC sub-items: warn if tasks lack acceptance criteria

      5. 🔳 Check completable items
         - Flag phases where all tasks `[x]` but phase still 🔄
         - Flag requirements where linked work done but still 🔄
         - Use `AskUserQuestion` before marking ✅

      6. 🔳 Triage Inbox items (if section exists)
         - For each item, propose to user: convert to requirement, add as phase task, move to Questions, or discard. Delete after.
         - Use `AskUserQuestion` to confirm any triage decisions

      7. 🔳 Present findings
         - Group issues by category
         - Show current state and proposed fix for each
         - Tell user await proceed before applying
    '';
  };
}
