{
  nixantic.sources.projects.commands."proj-load" =
    { scope }:
    {
      description = "Load project context from project / phases docs";
      arguments = [ { label = "Context"; } ];
      effort = "medium";
      asSkill = {
        opencode = true;
        pi = true;
      };
      content = ''
        Goal: load context about project / task from project docs.

        Do not load ${scope.commands."proj-load".reference} recursively.

        ## State

        ${scope.blocks."current-branch".embed}
        ${scope.blocks."project-files".embed}

        ## Instructions

        1. Ensure ${scope.skills."project-docs".reference} loaded.

        2. Read project doc
           * Use current branch / change state above, don't re-discover
           * If project files found:
             * Read FULLY main project doc context, checkpoint, requirements, progress
             * Don't re-read project symlink. Already in state above.
           * If "No project files", maybe uninitialized
             * STOP, inform user about missing context

        3. Read current/next phase docs mentioned in checkpoint/next steps
              Mindful of context window: don't read irrelevant old/future docs, but read relevant phase docs fully
              On ambiguity about next steps, ${scope.harness.prose.questions.request} to clarify next focus

        4.  Synthesize context & summarize current state
      '';
    };
}
