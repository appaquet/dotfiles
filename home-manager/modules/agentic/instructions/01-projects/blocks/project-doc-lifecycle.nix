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

          Project instructions name the repository's docs root. When they are silent, the docs root is `docs/features/` relative to the repository root.
          * Project folder: `<docs-root>/<yyyy>/<mm>/<dd>-<project-name>/` (run `date +%Y/%m/%d` to get it)
          * Main document: `00-<project-name>.md` inside the project folder
          * Phase documents: `01-<phase-name>.md`, `02-<phase-name>.md`, and so on; numbers establish ordering
          * The repository-root `proj/` symlink points to committed project files; `proj-adhoc/` points to ad-hoc or temporary project files
          * Create links only from the workspace root: `agentic-proj-create <project-folder>` for the committed link once that folder and its documents exist, `agentic-proj-create-adhoc` for the ad-hoc link; never create a link with `ln`
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

        ${scope.forHarness {
          pi = ''
            ### Sessions

            Sessions sections list the sessions that contributed to the document, in chronological order; append an entry when a session's planning, work, or investigation is recorded.
            * Each entry records the full session ID, the absolute transcript file path when known, and a concise purpose. When the transcript path is unknown, the entry omits the path.
            * Record no entry when the session has no session ID.
            * Keep one entry per session; a resumed session keeps its ID, so amend the existing entry instead of duplicating it.
            * Obtain the exact current values with `printf '%s\n' "$PI_SESSION_ID" "$PI_SESSION_FILE"`; never use a broad `env | grep PI_` dump.
            * Project and phase documents remain authoritative; linked transcripts are private and may be inspected or delegated when useful.
            * Example entries:
              ```markdown
              * <full-session-id> /abs/path/to/transcript.jsonl: Planned phase 01 scope
              * <full-session-id>: Investigated concurrency limits
              ```
          '';
          default = "";
        }}

          ### Document version control

          * For a committed project, keep the `proj` symlink in its own commit named `private: proj - <project-name>`. That commit contains the symlink only; never mix document changes into it.
          * For a committed project, keep `00-*.md`, `01-*.md`, and other document-file changes in a dedicated document-only commit prefixed `private: agent: docs -`. Include no code or symlink, and follow the repository version-control rule for the exact workflow.
          * When a user-invoked workflow requires committing project documents, batch all document updates made by that workflow. Review the combined document diff and commit it once after the final document-update step; do not commit individual tasks, findings, or intermediate updates separately.
          * Never commit `proj-adhoc`, its temporary target, or its project and phase documents.
      '';
    };
}
