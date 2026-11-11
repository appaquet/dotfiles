{
  nixantic.sources.version-control.commands."pr-desc" =
    { scope }:
    {
      description = "Generate a pull request description with summary and implementation notes";
      arguments = [ { label = "Focus"; } ];

      content = ''
        Goal: delegate a pull requestion description summary and implementation notes to a sub-agent

        ## Instructions

        Delegate to the agent and the assignment below. Wait for completion and return its report unchanged.

        Give the sub-agent this assignment:
        1. Load ${scope.skills."version-control".reference}

        2. Run `agentic-vcs-context`, stay in the reported workspace, and inspect `jj-diff-branch --git` plus relevant surrounding code.
          * Work read-only: do not edit files/project documents, change VCS history/bookmarks, access PR services, or delegate further.
          * Use existing project docs as supporting context when useful, loading ${
            scope.skills."project-docs".reference
          } before reading them. Code is authoritative; missing docs are not a blocker.
          * If there are no changes or evidence is incomplete, say so rather than inventing a report.

        3. Load ${scope.skills."human-writer".reference} for tone (no AI filler, no superlatives).
           Wrap identifiers (types, functions, files, fields) in backticks.

        4. Create a report using the format below, wrapped in a fenced markdown code block.
            * Per-component breakdown — analysis scaffolding, not the final PR text:
              * Group changes by logical component (directory, module, or feature area)
              * For each component, list changes by category (skip empty):
                * Added: New files, features, capabilities
                * Changed: Modified behavior, refactored code
                * Fixed: Bug fixes, corrections
                * Removed: Deleted files, deprecated features

            * Summary/implementation split rule:
              * Summary: WHAT changed for a consumer (behavior, API, errors, fixes). Avoid internal
                identifiers unless consumer-visible
              * Implementation Notes: HOW it was built (types, refactors, algorithms, structural changes)

        ```markdown
            ## Summary

            * [Observable/user-facing change — behavior, API surface, error responses, bug fixes]
            * [One bullet per distinct change, 1-3 lines, with concrete identifiers]

            ### Implementation Notes

            * **[Component or pattern]**: [How it is built — named types, algorithm, data flow]
            * **[Another component]**: [Detail]
        ```
      '';
    };
}
