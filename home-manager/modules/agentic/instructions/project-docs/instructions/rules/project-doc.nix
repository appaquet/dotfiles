{
  nixantic.sources.project-docs.instructions."rules/project-doc" = rec {
    heading = "Project Doc Structure";
    content = ''
      Project/feature docs spanning potentially multiple PRs. Docs updated continuously. Context window ephemeral, docs durable. Should show history, append/amend, not rewrite.

      ## File Location
      Unless project instructions specify otherwise:
      * Project folder: `docs/features/<yyyy>/<mm>/<dd>-<project-name>/` (run `date +%Y/%m/%d` to get it)
      * Main doc: `00-<project-name>.md` inside the folder
      * Phase docs: `01-<phase-name>.md`, `02-<phase-name>.md`, etc. (numbered for ordering)
      * Symlink: `proj/` at repo root pointing to the project folder
      * To print location of `proj` and its content, run `claude-proj-docs`

      ## Version control
      * `proj` symlink should be in jj change with desc `private: proj - <project-name>`
        * Contains symlink file, nothing else. Never mix doc changes into it.
        * Don't prefix with `claude:`
      * Doc file changes (00-*.md, 01-*.md, etc.)
        * jj change desc: `private: claude: docs -`
        * Only doc files, no code or symlink. Use jj fileset to commit/squash doc files.

      ## Creation & update
      * Proj docs: created via `proj-init`
      * Phase docs: Created with project doc, `ctx-plan`. If phase doc unrelated to new work, ask user if split. Updated on task complete, on `ctx-save` call, significant new info, uncertainties, decisions, insights, etc.
      * Use SR&ED methodology to capture context, uncertainties, decisions, learnings, advancements, conclusion

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
      Order: Context, Checkpoint, Inbox (opt.), Requirements, Questions & Investigations (opt.), Phases, Files

      ### Context
      Purpose and scope of changes

      ### Checkpoint
      Brief 1-2 paragraph summary for resuming work. References phase (if applicable), tasks worked on,
      and next step if decided/obvious. Updated by `/ctx-save`, preserved until next save overwrites

      ### Inbox (optional)
      Unprocessed user items (feedback, bugs, ideas, tasks). Don't take action on them, user will edit and tell you when.

      ### Requirements
      Requirements define WHAT (obs. behavior) to build, not HOW (impl.).
      Acceptance criteria (ACs) on tasks define DONE. Verifiable conditions per task.

      #### Req. format
      * R-numbered with status markers: `R1: ⬜ Description`
      * Sub-levels when needed: R1.1, R1.2
      * Phase annotation: `(Phase: Auth)` - by name, not number
      * Tasks reference requirements: `[ ] Implement X (R1, R2.1)`
      * Status markers: ⬜ Not started, 🔄 In progress, ✅ Complete
      * Out of scopes (OOS) can be added as sub-sections under requirements
      * Example:
        ```markdown
        * R1: ⬜ Core feature description (Phase: Setup)
          * R1.1: Sub-requirement if hierarchical
        * R2: 🔄 Another essential feature (Phase: Auth)
        * R3: ✅ Important supplementary feature (Phase: Setup)
        ```
      #### Req. rules
      * Read ALL existing req before create/update
      * Update existing rather than create parallel ones
      * All req go in ONE section, not breaking down (other than OOS)
      * Group related req logically when helpful
      * Always ask user before marking requirement complete. Never assume, ask.

      ### Questions & Investigations (optional)
      Checklist of questions, decisions, and investigation records. Capture uncertainties when encountered, outcomes when discovered. Update continuously.

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

      #### Phases format
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
      #### Phase rules
      * Update summary when scope changes significantly
      * You NEVER mark phases ✅, ask user if you think done
      * When resuming: if multiple phases 🔄, ask user focus

      ### Files
      Modified or important context files. Update after modifications
      * Exclude: generated files (`*.pb.go`, `*_grpc.pb.go`, wire), project docs
      * Include: crucial files even if unmodified
      * Format: `- **path/file.ext**: Purpose. Changes (if any).`
      * Never replace files list with redirects like "See [phase doc] for details"
      * Should mention phase in which got modified. Don't remove previous ones, always include all of them
    '';

    phasesDoc = ''
      ### Sections
      Keep ordered. Never reorder/rename/create more sections. Some optional (opt)
      Order: Context, Requirements (opt.), Questions & Investigations (opt.), Tasks, Files

      ### Context
      Brief context + referencing project doc via markdown link.

      ### Requirements (optional)
      Only needed when expanding project doc requirements with phase-specific details.

      * Same rules as project doc
      * Numbering: Derive parent R-number: `R5.A`, `R5.B` (never top-level `R1`, ...)
      * Refererence in project doc: `R5: ⬜ Feature X (Phase: Auth, see R5.A-C in phase doc)`

      ### Questions & Investigations (optional)
      Phase-specific questions, decisions, and investigation records. Same format as project doc.

      ### Tasks
      Flat checkmark list of work items

      #### Tasks format
      * Status markers: `[ ]` Not started, `[~]` In progress, `[x]` Complete
      * Should reference requirements when applicable
      * Should have AC sub-items for each task, defining clear verifiable conditions for completion
      * Example:
        ```
        - [ ] Implement X (R1, R2.1)
          - AC: specific verifiable condition
        ```
      #### Tasks rules
      * Should be actionable, with clear AC, without need to read code. AC maps to assertion. Task done when all ACs pass.
      * When start work on task, mark in progress
      * When start work on phase, mark in progress
      * You can mark tasks `[x]` after completing them (not phases!)
      * Each item = discrete, independent work unit

      ### Files
      Files relevant to this phase. Update after modifications. Same rules as project doc, but phase-specific.
    '';
  };
}
