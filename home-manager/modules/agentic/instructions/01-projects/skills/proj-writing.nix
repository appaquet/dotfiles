{
  nixantic.sources.projects.skills."proj-writing" = {
    kind = "directory";
    main =
      { scope }:
      {
        description = "Skill for writing and updating project & phase docs";

        content = ''
          # Project & phase documentation writing skill

          Docs updated continuously as we plan, develop, review, etc.. Because context window ephemeral while docs durable. Should show history, append/amend, not rewrite.
          Update docs via the active project link (`proj` or `proj-adhoc`) reported by project state, as permissions may only allow that.

          ## Project docs creation
          - Create project and phase files only when an active user-invoked workflow explicitly directs creation; do not create them independently.
          - If no active creation workflow directs creation, stop and ask the user to invoke an appropriate project workflow.
          - If a phase doc is unrelated to new work, ask the user if it should be split. Update docs on task completion, when ${
            scope.commands."proj-save".reference
          } is run, significant new info, uncertainties, decisions, insights, etc.

          ## Version control
          - For committed projects, keep the `proj` symlink in its own commit named `private: proj - <project-name>`
            - Contains the symlink file only. Never mix doc changes into it.
          - For committed projects, keep doc file changes (00-*.md, 01-*.md, etc.) in a dedicated doc-only commit prefixed `private: agent: docs -`
            - Only doc files, no code or symlink.
            - Follow the repository version control rule for the exact workflow.
          - Never commit `proj-adhoc`, its temporary target, or its project and phase documents.

          ## Overall writing rules
          - Clear, concise, informative.
          - Append/amend only, don't rewrite history.
          - Should follow a SR&ED style, showing uncertainties, hypotheses, experiments, decisions, outcomes, etc.
          - Respect section ordering rules.

          ## Project doc writing rules

          ### Project requirements rules
          - Requirements should be non-overlapping, non-redundant, self-contained, clear, concise, and testable.
          - Read ALL existing req before create/update
          - Update existing rather than create parallel ones
          - All req go in ONE section, not breaking down (other than OOS)
          - Group related req logically when helpful
          - Always ask user before marking requirement complete. Never assume, ask.

          ### Project phases rules
          - Update summary when scope changes significantly
          - You NEVER mark phases ✅, ask user if you think done
          - When resuming: if multiple phases 🔄, ask user focus

          ### Files rules
          - Exclude: generated files (`*.pb.go`, `*_grpc.pb.go`, wire), project docs
          - Include: crucial files even if unmodified
          - Never replace files list with redirects like "See [phase doc] for details"
          - Should mention phase in which got modified. Don't remove previous ones, always include all of them
          - If too many in project files, put directories, but link to phases & make sure phases have full file list.

          ## Phase doc writing

          ### Phase requirements rules
          - Same rules as project doc
          - Numbering: Need to derive parent R-number: `R5.A`, `R5.B` (never top-level `R1`, ...)
          - Refererence in project doc: `R5: ⬜ Feature X (Phase: Auth, see R5.A-C in phase doc)`

          ### Phase tasks rules
          - Should be actionable, with clear AC, without need to read code. AC maps to assertion. Task done when all ACs pass.
          - When start work on task, mark in progress
          - When start work on phase, mark in progress
          - You can mark tasks `[x]` after completing them (not phases!)
          - Each item = discrete, independent work unit
          - Specifies the selected agent when relevant; select it using ${scope.blocks.sub-agent-selection.reference}

          ### Phase files rules
          - Should include all files relevant to the phase, even if not modified in current work session
          - Update after implementation.
        '';
      };
    files = { };
  };
}
