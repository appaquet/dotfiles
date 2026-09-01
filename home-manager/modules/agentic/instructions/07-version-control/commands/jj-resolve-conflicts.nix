{
  nixantic.sources.version-control.commands."jj-resolve-conflicts" =
    { scope }:
    {
      when = { scope }: scope.settings.versionControl.mode == "jj";
      description = "Resolve jj conflicts in the current change stack, oldest to newest";

      arguments = [ { label = "Context"; } ];

      effort = "xhigh";

      content = ''
        Goal: resolve conflicts across stacked changes, processing oldest first so fixes cascade.

        Before reading, interpreting, or updating project or phase documents, load ${
          scope.skills."project-docs".reference
        }.

        ## Instructions

        1. 🔳 Create a new phase in project documentation for this resolution session.
           - Should be a sub-phase of the latest phase worked on. E.g. phase 1 -> phase 1a.
           - If no project documentation exists, stop and report the missing planning context; do not run `jj edit` or edit conflict markers
           - Follow the project-document version-control instructions for the new phase files

        2. 🔳 Plan the resolution
           - `jj log` to identify all conflicting changes (marked with `(conflict)`), oldest to newest
           - Note the original `@` change ID to return to afterward
           - To get a sense of the issues, `jj edit <change_id>` into a conflicting change and `jj resolve --list` to capture its conflicting files, then `jj edit <original_change_id>` back
           - In the new phase, one task per conflicting change, oldest-to-newest, each with verifiable acceptance criteria (resolved files, zero conflicts after that change), plus a final return/verify task
           - If planning surfaces questions, stop and report them before editing conflict files; otherwise continue

        3. 🔳 Resolve conflicts oldest-to-newest
           - `jj edit <change_id>` into the oldest conflicting change; mark its phase task `[~]`
           - `jj resolve --list` to see conflicting files
           - For each conflicted file: read it, understand both sides, combine both contributions — never drop content from either side — and remove all conflict markers
           - Mark the task `[x]` once its acceptance criteria pass
           - `jj log` to check if the fix cascaded to descendants; if they still conflict, move to the next oldest and repeat

        4. 🔳 Return and verify
           - `jj new <original_change_id>` to create a new empty change on top of where we started
           - `jj log` to confirm zero conflicts remain
           - Update the final verify task with the affected changes and files and the outcome
           - Mark the task `[x]` only when its acceptance criteria pass; if conflicts remain, leave it tracked as `[~]` with a blocker
           - Report what was resolved
      '';
    };
}
