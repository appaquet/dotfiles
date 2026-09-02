{
  nixantic.sources.projects.blocks."project-doc-lifecycle" =
    { scope }:
    {
      content = ''
        ## Project documention files lifecycle

        Project and phase documents are the durable source of truth for project state. They are created, updated, and maintained throughout the project lifecycle. 
        Agent should be considered amnesic. Context is limited and compaction/reset may happen at any time, so project and phase documents are the only reliable source of truth.
        They need to be well maintained, and be usable at any point in time for reloading context.

        ### Locations

        Unless project instructions specify otherwise:
        * Project folder: `docs/features/<yyyy>/<mm>/<dd>-<project-name>/` (run `date +%Y/%m/%d` to get it)
        * Main document: `00-<project-name>.md` inside the project folder
        * Phase documents: `01-<phase-name>.md`, `02-<phase-name>.md`, and so on; numbers establish ordering
        * The repository-root `proj/` symlink points to committed project files; `proj-adhoc/` points to ad-hoc or temporary project files
        * Run `agentic-proj-docs` to print the location and contents of `proj` or `proj-adhoc`

        ### Creation and updates

        * Create project and phase files only when an active user-invoked workflow explicitly directs their creation. Otherwise, stop and ask the user to invoke an appropriate project workflow.
        * Use the active project link (`proj` or `proj-adhoc`) reported by project state; permissions may allow only that location.
        * Update documents continuously during planning, development, review, and other work: on task completion, when ${
          scope.commands."proj-save".reference
        } runs, and when significant information, uncertainties, decisions, insights, or outcomes arise.
        * If new work is unrelated to a phase document, ask the user whether to split it into a separate phase document.
        * Never ask me at end of implementation if tasks/phases/requirements can be marked as complete. Instead, debrief on current what was done, and next step expectations.
        * Completion should be determined by the user, but can be recommended when the user engage with a next step without marking previous tasks/phases/requirements as complete.

        ### Writing and history

        * Write clearly, concisely, and informatively. Respect the required section ordering.
        * Preserve project history by appending or amending it rather than rewriting it. Use an SR&ED style that records uncertainties, hypotheses, experiments, decisions, and outcomes.
        * The project Checkpoint is deliberately replaceable current-state information; replacing it does not replace project history.

        ### Document version control

        * For a committed project, keep the `proj` symlink in its own commit named `private: proj - <project-name>`. That commit contains the symlink only; never mix document changes into it.
        * For a committed project, keep `00-*.md`, `01-*.md`, and other document-file changes in a dedicated document-only commit prefixed `private: agent: docs -`. Include no code or symlink, and follow the repository version-control rule for the exact workflow.
        * When a user-invoked workflow requires committing project documents, batch all document updates made by that workflow. Review the combined document diff and commit it once after the final document-update step; do not commit individual tasks, findings, or intermediate updates separately.
        * Never commit `proj-adhoc`, its temporary target, or its project and phase documents.
      '';
    };
}
