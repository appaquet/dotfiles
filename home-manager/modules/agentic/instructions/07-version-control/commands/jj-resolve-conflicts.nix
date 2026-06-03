{
  nixantic.sources.version-control.commands."jj-resolve-conflicts" = {
    when = { scope }: scope.settings.versionControl.mode == "jj";
    description = "Resolve jj conflicts in the current change stack, oldest to newest";

    effort = "xhigh";

    content = ''
      Goal: resolve conflicts across stacked changes, processing oldest first so fixes cascade.

      ## Instructions

      1. 🔳 Survey conflicts
         - Run `jj log` to see the full stack
         - Identify all conflicting changes (marked with `(conflict)`)
         - Note the original `@` change ID to return to afterward
         - If no conflicts, report and stop

      2. 🔳 Process each conflict oldest-to-newest
         - `jj edit <change_id>` into the oldest conflicting change
         - `jj resolve --list` to see conflicting files
         - For each conflicted file:
           - Read the file, find conflict markers (`<<<<<<<`, `>>>>>>>`)
           - Understand both sides: what the destination added vs what our change added
           - Combine both contributions — never drop content from either side
           - Remove all conflict markers
         - After resolving, `jj log` to check if fix cascaded to descendants
         - If descendants still conflict, move to next oldest and repeat
         - If all clear, done

      3. 🔳 Return and verify
         - `jj new <original_change_id>` to create a new empty change on top of where we started
         - `jj log` to confirm zero conflicts remain
         - Report what was resolved
    '';
  };
}
