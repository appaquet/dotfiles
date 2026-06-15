{
  nixantic.sources.projects.commands."proj-save" =
    { scope }:
    {
      description = "Update project and phase docs with current state and progress";
      effort = "medium";
      asSkill = {
        opencode = true;
      };
      content = ''
        Goal: Save project state for perfect resumption. Detail level should allow anyone, including a junior intern, to pick up where we left off. You may not be the one resuming it, be thorough and clear.

        ## State

        ${scope.blocks."project-files".embed}

        ## Instructions

        1. Ensure ${scope.skills."proj-writing".reference} loaded.

        2. 🔳 Note `proj` symlink from state above. Identify current phase from checkpoint or ask user

        3. 🔳 Update current phase doc(s)
           * Requirements
             * Read/validate current requirements
             * Update or add new ones if needed based on work done
             * Bubble up to main doc if needed
           * Design
             * If needed, update with any design decisions made during work
           * Questions & investigations
             * Add resolved phase related questions if any
             * Add new if arose during work
           * Tasks
             * Update statuses (validate ACs)
             * Add new discovered
           * Files
             * Update with changes

        4. 🔳 Update other impacted phases docs
           * Any changes in context, requirements, design choices may impact multiple phases, make sure to review and update them all accordingly
           * Check modified files, good indicator of impacted phases. Generic review/docs phases are usually impacted by any changes. When we just conducting review, it usually involves changes in multiple phases.

        5. 🔳 Update main project doc
           * Requirements
             * Read/validate current requirements
             * Update or add new ones if needed based on work done
             * Bubble down to phase docs if needed
           * Design
             * If needed, update with any design decisions made during work
           * Questions & Investigations
             * Add resolved questions if any
             * Add new questions if arose during work
           * Phases
             * If all phase tasks complete, ask user if phase complete
           * Files
             * Update with summary, with phase reference
           * Checkpoint
             * Replace with summary of work done, phase & tasks
             * Update next step if decided/obvious
             * Keep short like project docs mention

        6. 🔳 Commit doc changes
           * Use the project doc version control guidelines
      '';
    };
}
