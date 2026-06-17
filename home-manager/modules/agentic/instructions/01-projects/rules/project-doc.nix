{
  nixantic.sources.projects.blocks."project-doc-recall" =
    { scope }:
    {
      preFlightRecall = "ALWAYS use project & phase docs to plan and track work as per project doc rules. When writing project/phase docs, use ${
        scope.skills."proj-writing".reference
      }. Don't load it until you need to create or update them.";
      content = "";
    };

  nixantic.sources.project-docs.instructions."rules/project-doc" =
    { scope }:
    rec {
      heading = "Project Doc Structure";

      content = ''
        Project/feature docs spanning potentially multiple PRs. Source of truth as context window ephemeral.

        Before authoring project docs, make sure ${scope.skills."proj-writing".reference} loaded.

        ## File Location
        Unless project instructions specify otherwise:
        * Project folder: `docs/features/<yyyy>/<mm>/<dd>-<project-name>/` (run `date +%Y/%m/%d` to get it)
        * Main doc: `00-<project-name>.md` inside the folder
        * Phase docs: `01-<phase-name>.md`, `02-<phase-name>.md`, etc. (numbered for ordering)
        * Symlink: `proj/` at repo root pointing to the project folder
        * To print location of `proj` and its content, run `agentic-proj-docs`

        ## Creation & update
        Always via ${scope.skills."proj-writing".reference}.

        ## Project Doc (00-XYZ.md)
        Overview and navigation. Requirements live here. Tasks do NOT

        ${projectDoc}

        ## Phase Doc (01-XYZ.md, 02-XYZ.md, ...)
        Where work happens. All tasks live here. Never directly in project doc.

        ${phasesDoc}
      '';

      projectDoc = ''
        ### Sections
        Keep ordered. Never reorder/rename/create more sections. Some optional (opt)
        Order: Context, Checkpoint, Inbox (opt.), Requirements, Design, Questions & Investigations (opt.), Phases, Files

        ### Context
        Precise goal of the project + brief context project

        ### Checkpoint
        Brief 1-2 paragraph summary for resuming work. References current & next phases (if applicable), tasks worked on, and next step if decided/obvious. Updated by ${
          scope.commands."proj-save".reference
        }, preserved until next save overwrites. Always keep short, focusing on now and next. History is kept through phases, not checkpoint.

        ### Inbox (optional)
        Unprocessed user items (feedback, bugs, ideas, tasks). Don't take action on them, user will edit and tell you when.

        ### Requirements
        Requirements define WHAT (obs. behavior) to build, not HOW (impl.).
        Acceptance criteria (ACs) on tasks define DONE. Verifiable conditions per task.

        #### Req. format
        * R-numbered with status markers (R1, R2) w/ sub-levels when needed (R1.1, R1.2)
        * Status markers: ⬜ Not started, 🔄 In progress, ✅ Complete
        * Phase annotation: `(Phase: Auth)`. By name, not number
        * Out of scopes (OOS) can be added as sub-sections under requirements
        * Example:
          ```markdown
          * R1: ⬜ Core feature description (Phase: Setup)
            * R1.1: Sub-requirement if hierarchical
          * R2: 🔄 Another essential feature (Phase: Auth)
          * R3: ✅ Important supplementary feature (Phase: Setup)

        ### Design (optional)
        High-level design decisions and architecture. Should use ASCII diagrams for visual clarity.
        Should be updated as design / phases evolve.

        ### Questions & Investigations (optional)
        Checklist of questions, decisions, and investigation records. Capture uncertainties when encountered, outcomes when discovered. Every questions asked during planning/implementation, with answers, should be captured. Update continuously.

        Format:
        ```markdown
        * [x] Q: Can we use X for Y?
          * Uncertainty: Unknown if X supports concurrent Z
          * Tried: Prototype with X, hit limitation W
          * Result: Switched to V, handles concurrency natively
        * [ ] Q: Will approach A scale to N?
        ```

        ### Phases
        List of phase references. No task items here.
        * Phases numbered for ordering (NN), can use letter (NNa) for sub-phases/inserted
        * Status markers: ⬜ Not started, 🔄 In progress, ✅ Complete
        * Includes link to phase doc.
        * Always include 2-3 sentence summary.
        * Example:
          ```markdown
          ### 🔄 01 Phase: Auth
          [01-auth](01-auth.md)

          Implement OAuth2 flow with JWT tokens. Adds login/logout endpoints and session management
          ```
        ### Files
        Modified or important context files. Update after modifications
        May be directory if too many files, but make sure in phases + links to phases.
        Format: `- **path/file.ext**: Purpose. Changes (if any).`
      '';

      phasesDoc = ''
        ### Sections
        Keep ordered. Never reorder/rename/create more sections. Some optional (opt)
        Order: Context, Requirements (opt.), Design, Questions & Investigations (opt.), Tasks, Files

        ### Context
        Precise goal of the phase, aligned with goal of project + Brief context of phase

        ### Requirements (optional)
        Only needed when expanding project doc requirements with phase-specific details.

        ### Questions & Investigations (optional)
        Phase-specific questions, decisions, and investigation records. Same format as project doc.

        ### Design (optional)
        Phase-specific design decisions and architecture. Should follow same format as project doc design section, with ASCII diagrams when needed.

        ### Tasks
        Flat checkmark list of work items

        * Status markers: `[ ]` Not started, `[~]` In progress, `[x]` Complete
        * Reference requirements when applicable
        * AC sub-items for each task, defining clear verifiable conditions for completion
        * Example:
          ```
          - [ ] Implement X (R1, R2.1)
            - AC: specific verifiable condition
          ```

        ### Files
        Files relevant to this phase. Same rules/format as project doc.
      '';
    };
}
