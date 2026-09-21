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
          * Outside multi-question interviews, update documents continuously during planning, development, review, and other work: on task completion, when ${
            scope.commands."proj-save".reference
          } runs, and when significant information, uncertainties, decisions, insights, or outcomes arise.
          * During a multi-question interview, accumulate related questions, answers, decisions, uncertainties, and investigation outcomes in working context. Update the affected project and phase sections together at meaningful checkpoints: when a coherent topic or design branch resolves; before changing topic or phase, delegation, an approval or engagement gate, a planned stop, or a known context-loss boundary; and when the interview ends.
          * Do not update documents merely because an interview answer arrived. A checkpoint can follow one answer when it resolves a key branch. At an interruption checkpoint, persist unresolved questions and the next step. Skip the update when nothing accumulated. This does not change the timing of one-off decisions, explicit saves, task completion, implementation investigations, or SR&ED records.
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
            * Project and phase documents remain authoritative; linked transcripts hold details the documents may omit or summarize.
            * When loaded documents reference a session and your context lacks what that entry's purpose covers (fresh or compacted session), recover it from the referenced session ID or transcript path using ${
              scope.skills."pi-recaller".reference
            }. Broad transcript scans go to an Explore agent; keep bounded queries in-session.
            * Fold durable recovered facts into the document section they belong to, so later sessions do not depend on the transcript.
            * Example entries:
              ```markdown
              * <full-session-id> /abs/path/to/transcript.jsonl: Planned phase 01 scope
              * <full-session-id>: Investigated concurrency limits
              ```
          '';
          default = "";
        }}

          ### Document version control

          * Project and phase document changes remain as uncommitted working-copy changes. Never create a dedicated document commit. In a separate docs repository the user commits them when they choose; in the same repository they are part of the working change and ship with the work.
          * For a committed project, keep the `proj` symlink in its own commit named `private: proj - <project-name>`. That commit contains the symlink only; never mix document changes into it.
          * Review document changes as working-copy diffs (e.g. `jj diff` in the docs repo) before relying on them.
          * Never commit `proj-adhoc`, its temporary target, or its project and phase documents.
      '';
    };
}
