{
  nixantic.sources.version-control.commands."jj-resolve-conflicts" =
    { scope }:
    {
      when = { scope }: scope.settings.versionControl.mode == "jj";
      description = "Resolve jj conflicts in the current change stack, oldest to newest";

      arguments = [ { label = "Context"; } ];

      effort = "xhigh";

      content = ''
        Goal: resolve conflicts across the current Jujutsu stack, oldest first so each resolution can cascade through descendants.

        Before any project-document operation, load ${
          scope.skills."project-docs".reference
        }. Before any `jj` command, load ${scope.skills."version-control".reference}.

        ## Instructions

        1. 🔳 Create and plan a conflict-resolution sub-phase
           * Create a sub-phase of the latest phase worked on. If no project documentation exists, stop; do not move the working copy or edit conflict markers
           * Follow the document version-control rules in ${scope.skills."project-docs".reference}
           * Run `agentic-proj-docs` and record the absolute project folder before leaving the original tree. Do not update project documents while the working tree is on a historical conflicted change
           * Run an untruncated `jj ls`, then list current-stack conflicts oldest-first with `jj log -r '::@ & conflicts()' --reversed`
           * Determine the stable return revision: if `jj log -r @ --no-graph -T 'empty ++ "\n"'` is `true`, use `@-`; otherwise use `@`. Save its full ID with `jj log -r <return_revision> --no-graph -T 'change_id ++ "\n"'`
           * For every listed conflict, inspect paths with `jj resolve --list -r <full_change_id>` and contents with `jj file show -r <full_change_id> <path>`. This is read-only; do not use `jj edit` for planning
           * Create one phase task per initially observed conflicted change, oldest first, plus a final return-and-verify task. Give every task verifiable file, graph, and test acceptance criteria
           * Resolve design questions now. If the two sides are mutually exclusive designs or the intended result is unclear, stop and ask before changing the working tree

        2. 🔳 Resolve the oldest remaining conflict
           * Re-run `jj log -r '::@ & conflicts()' --reversed`. If it is empty, continue to return and verification
           * Select the oldest listed full change ID. Run `jj resolve --list -r <change_id>`; if it says no conflicts remain, re-check the graph instead of using a stale result
           * Run `jj ls` in a separate tool call and confirm the state is expected, then run `jj new <change_id>` to create an undescribed resolution child
           * Edit conflict markers manually. Do not run plain `jj resolve`; it invokes a merge tool
           * For each file, understand the diff-style marker block and preserve every contribution required by the agreed design. Remove all markers
           * Run `jj diff` and confirm it shows only the intended conflict resolution. Run `jj status` and inspect any literal marker hits from `jj file search -r @ -p '<<<<<<< conflict'`
           * Run `jj ls` in a separate tool call, confirm the resolution child is expected and has no unresolved conflicts, then run `jj squash -u`
           * Re-check the graph and repeat this step. Do not continue through a conflict list captured before the squash

        3. 🔳 Return to the original stack and verify
           * Run `jj ls` in a separate tool call, then `jj new <full_return_change_id>` to create a fresh empty change above the original stack position
           * Confirm `jj log -r @- --no-graph -T 'change_id ++ "\n"'` equals the saved return ID
           * Confirm `jj log -r '::@ & conflicts()'` is empty
           * Run `jj file search -r @ -p '<<<<<<< conflict'` and inspect every hit; no hit may be an unresolved marker
           * Run the tests or builds required by the parent phase and verify their actual results

        4. 🔳 Update project state and report
           * Only after the original tree and project link are restored, update the sub-phase tasks with each change's affected files and outcome. Record conflicts that disappeared through cascading rebases as auto-resolved
           * Mark tasks `[x]` only when their acceptance criteria pass. If conflicts or validation failures remain, leave the relevant task `[~]` with the blocker
           * Report the changes resolved, conflicts that cascaded away, verification results, and any unresolved blocker
      '';
    };
}
