{
  nixantic.sources.projects.blocks."project-doc-project" =
    { scope }:
    {
      content = ''
        ## Project document (`00-XYZ.md`)

        The project document provides overview and navigation. Requirements live here; tasks do not.

        ### Sections

        Keep sections ordered. Never reorder, rename, or create additional sections. Optional sections are marked `(optional)`.

        Order: Context, Checkpoint, Inbox (optional), Requirements, Design (optional), Questions & Investigations (optional), Phases, Files

        ### Context

        State the precise project goal and brief project context.

        ### Checkpoint

        Write a brief one- or two-paragraph resumption summary. Reference the current and next phases when applicable, the tasks just worked on, and the next step when decided or obvious. Preserve it until ${
          scope.commands."proj-save".reference
        } replaces it at the next save. Keep it short and focused on now and next; phases retain history.

        ### Inbox (optional)

        Hold unprocessed user feedback, bugs, ideas, and tasks. Do not act on an item; the user will edit it and direct the next action.

        ### Requirements

        Requirements define what observable behavior to build, not how to implement it. Task acceptance criteria define done through verifiable conditions.

        Requirements must be non-overlapping, non-redundant, self-contained, clear, concise, and testable.
        * Read all existing requirements before creating or updating one.
        * Update an existing requirement instead of creating a parallel one.
        * Keep all requirements in one section; do not break it down except for Out of Scope subsections.
        * Group related requirements logically when helpful.
        * Always ask the user before marking a requirement complete; never assume it is complete.

        #### Requirement format

        * Use R-numbering (`R1`, `R2`) with sub-levels when needed (`R1.1`, `R1.2`).
        * Use status markers: `⬜` Not started, `🔄` In progress, `✅` Complete.
        * Annotate each requirement with its phase by name, not number: `(Phase: Auth)`.
        * Add Out of Scope (OOS) items only as subsections under Requirements.
        * Example:
          ```markdown
          * R1: ⬜ Core feature description (Phase: Setup)
            * R1.1: Sub-requirement if hierarchical
          * R2: 🔄 Another essential feature (Phase: Auth)
          * R3: ✅ Important supplementary feature (Phase: Setup)
          ```

        ### Design (optional)

        Record high-level design decisions and architecture. Use ASCII diagrams for visual clarity and update this section as the design or phases evolve.

        ### Questions & Investigations (optional)

        Maintain a checklist of questions, decisions, and investigation records. Capture uncertainties when encountered and outcomes when discovered. Record every question asked during planning or implementation with its answer, and update this section continuously.

        Format:
        ```markdown
        * [x] Q: Can we use X for Y?
          * Uncertainty: Unknown if X supports concurrent Z
          * Tried: Prototype with X, hit limitation W
          * Result: Switched to V, handles concurrency natively
        * [ ] Q: Will approach A scale to N?
        ```

        ### Phases

        List phase references only; do not put task items here.
        * Number phases for ordering with `NN`; use a letter such as `NNa` for inserted or sub-phases.
        * Use status markers: `⬜` Not started, `🔄` In progress, `✅` Complete.
        * Include a link to each phase document and an always-present two- or three-sentence summary.
        * Update a phase summary when its scope changes significantly.
        * Never mark a phase `✅`; ask the user when it appears complete.
        * When resuming and multiple phases are `🔄`, ask the user which phase to focus on.
        * Example:
          ```markdown
          ### 🔄 01 Phase: Auth
          [01-auth](01-auth.md)

          Implement OAuth2 flow with JWT tokens. Adds login/logout endpoints and session management.
          ```

        ### Files

        List modified or important context files and update the list after modifications.
        * Exclude generated files (`*.pb.go`, `*_grpc.pb.go`, wire) and project documents.
        * Include crucial files even when unmodified.
        * Identify the phase in which each file changed. Do not remove prior entries or replace the list with redirects such as "See [phase doc] for details".
        * If the list is too large, list directories instead, link to the relevant phases, and ensure those phase documents contain the complete file lists.
        * Format: `- **path/file.ext**: Purpose. Changes (if any).`
      '';
    };
}
