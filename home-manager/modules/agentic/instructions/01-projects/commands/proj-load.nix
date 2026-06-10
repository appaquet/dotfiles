{
  nixantic.sources.projects.commands."proj-load" =
    { scope }:
    {
      description = "Load project context from project / phases docs";
      effort = "medium";
      asSkill = {
        opencode = true;
      };
      content = ''
        Goal: load context about project / task from project docs.

        Don't load ${
          scope.skills."proj-load".reference
        }: this is the ${scope.skills."proj-load".name} skill.

        ## State

        ${scope.blocks."current-branch".embed}
        ${scope.blocks."project-files".embed}

        ## Instructions

        1. 🔳 Read project doc
           * Use current branch / change state above, don't re-discover
           * If project files found:
             * Read FULLY main project doc context, checkpoint, requirements, progress
             * Don't re-read project symlink. Already in state above.
           * If "No project files", maybe uninitialized
             * STOP, inform user about missing context

        2. 🔳 Read current/next phase docs mentioned in checkpoint/next steps
              Mindful of context window: don't read irrelevant old/future docs, but read relevant phase docs fully
              On ambiguity about next steps, `AskUserQuestion` to clarify next focus

        3. 🔳 Synthesize context & summarize current state
      '';
    };
}
