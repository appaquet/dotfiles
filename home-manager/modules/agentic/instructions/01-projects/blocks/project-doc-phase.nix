{
  nixantic.sources.projects.blocks."project-doc-phase" =
    { scope }:
    {
      content = ''
        ## Phase document (`01-XYZ.md`, `02-XYZ.md`, ...)

        Phase documents are where work happens. All tasks live here, never directly in the project document.

        ### Sections

        Keep sections ordered. Never reorder, rename, or create additional sections. Optional sections are marked `(optional)`.

        Order: Context, Requirements (optional), Design (optional), Questions & Investigations (optional), Tasks, Files

        ### Context

        State the precise phase goal, aligned with the project goal, and brief phase context.

        ### Requirements (optional)

        Add this section only when expanding project-document requirements with phase-specific detail. Follow the project requirement rules and derive identifiers from the parent requirement: `R5.A`, `R5.B`, never a new top-level `R1`.

        Reference derived requirements from the project document, for example: `R5: ⬜ Feature X (Phase: Auth, see R5.A-C in phase doc)`.

        ### Design (optional)

        Record phase-specific design decisions and architecture. Follow the project Design rules, using ASCII diagrams when needed.

        ### Questions & Investigations (optional)

        Record phase-specific questions, decisions, and investigation records. Follow the project Questions & Investigations rules and format.

        ### Tasks

        Use a flat checkmark list of discrete, independent work items.
        * Use status markers: `[ ]` Not started, `[~]` In progress, `[x]` Complete.
        * Make each task actionable and precise, with a clear expected outcome, code pointers, and enough relevant context that another engineer can complete it without reading the code first.
        * Reference applicable requirements.
        * Give every task acceptance-criteria sub-items with clear, verifiable conditions. Each acceptance criterion maps to an assertion; a task is complete only when all its acceptance criteria pass.
        * Mark a task `[~]` when starting it and mark the phase `🔄` when starting it. You may mark completed tasks `[x]` after completing them, but never mark the phase complete.
        * Specify the selected agent when relevant; select it using ${scope.blocks.sub-agent-selection.reference}.
        * Example:
          ```markdown
          - [ ] Implement X (R1, R2.1)
            - AC: specific verifiable condition
          ```

        ### Files

        List all files relevant to the phase, including files not modified in the current work session. Follow the project Files format and update this list after implementation.
      '';
    };
}
