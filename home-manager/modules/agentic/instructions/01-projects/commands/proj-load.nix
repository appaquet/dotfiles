{
  nixantic.sources.projects.commands."proj-load" = {
    description = "Load project context from project / phases docs";
    effort = "medium";
    asSkill = {
      opencode = true;
    };
    content = ''
      Goal: load context about project / task from project docs.

      Don't load proj-load skill: this is the proj-load skill.

      ## State

      * Current branch: !`jj-current-branch`
      * Project files:
        ```
        !`claude-proj-docs`
        ```

      ## Instructions

      1. 🔳 Read project docs (use state above, don't re-discover)
         * If project files found:
           * Read main project doc context, checkpoint, requirements, progress
           * Don't re-read project symlink. Already in state.
         * If "No project files", maybe uninitialized
           * STOP, inform user about missing context

      2. 🔳 Load current/next phase docs mentioned in checkpoint/next steps
            Mindful of context window: don't read irrelevant old/future docs
            On ambiguity about next steps, `AskUserQuestion` to clarify next focus

      3. 🔳 Synthesize context & summarize current state
    '';
  };
}
