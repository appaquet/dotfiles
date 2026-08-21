{
  nixantic.sources.version-control.commands."jj-absorb" =
    { scope }:
    {
      when = { scope }: scope.settings.versionControl.mode == "jj";
      description = "Distribute files from current change into their matching ancestor changes in the stack";

      argumentHint = "[change-id]";

      content = ''
        Goal: Distribute files from a change (default: `@`) into ancestor changes that last modified them.

        Only targets changes within the current stacked branch (from `jj-stacked-stats`).
        Useful after review fixes, bulk edits, or any work touching files across multiple stacked changes.

        Source: `$ARGUMENTS` (change to absorb from, defaults to `@`)

        ## Instructions

        1. 🔳 Survey the stack
            - Run `jj-stacked-stats` to see all stacked branch changes and their files
            - Run `jj diff --stat -r <source>` to see files to distribute
            - If no files to distribute, report and stop

        2. 🔳 Match files to targets
            - Only consider changes visible in `jj-stacked-stats` as targets
            - For each file in the source, find the most recent stacked change that modified it
            - NEVER target an earlier change when a more recent one also modified the same file —
              squashing into earlier changes causes cascading conflicts in all descendants.
              "Most recent" is the rule, not "semantically best fit"
            - Files with no direct match: assign to the most semantically related change based on
              its description and the other files it contains
            - Group files by target change

        3. 🔳 Present plan
            - Show table: target change (short id + description) → files to absorb
            - Show any unmatched files (will remain in source)
            - Wait for user confirmation before proceeding

        4. 🔳 Execute squashes
            - For each target group: `jj squash -u -f <source> -t <target> <files...>`
              `-u` keeps destination message as-is, preventing editor popup that blocks execution
            - After all squashes, run `jj log` to check for conflicts

        5. 🔳 Handle conflicts (if any)
            - If conflicts appear, run ${scope.commands."jj-resolve-conflicts".reference}
            - After resolution, verify stack is clean

        6. 🔳 Verify final state
            - `jj-stacked-stats` to show final stack
            - Note if source change is now empty (user decides whether to abandon)
            - Report what was absorbed where
      '';
    };
}
