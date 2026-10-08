{
  nixantic.sources.version-control.skills."version-control" = {
    kind = "directory";
    main =
      { scope }:
      {
        description = "Use this skill the moment you are about to run a version-control command (jj & git), including need to look at repository state: status, log, diffs, commits, branches, merges, rebase intent, etc.";
        content = ''
          # Version Control (Jujutsu)

          We use Jujutsu (`jj`) in colocated git repositories. The git checkout is always detached; use `jj` for writes and use `git` only for an unavoidable read-only query.

          ## Mental model

          * `@` is this workspace's working-copy change; `@-` is its parent. Each workspace has its own `@`
          * Every `jj` command snapshots non-ignored working-copy files automatically. There is no staging area, and an empty `@` is normal
          * A change ID identifies an evolving change and normally survives rewrites; its commit ID changes on every rewrite
          * Save the full change ID for a durable handle. A shortest prefix can become ambiguous as the graph grows, and an empty undescribed `@` can be abandoned when you leave it
          * Bookmarks are the branch equivalent; `trunk()` is the main immutable base
          * `jj new`, `jj edit`, and workspace switches replace the tracked working tree. Files absent from the destination disappear from disk until you return
          * We use colocated repos, git `HEAD` stays detached at `@-` (the working change's parent): the `HEAD` commit never contains working-copy changes, and only `jj commit` moves it
          * jj keeps the git index roughly in sync but with empty-blob placeholders for new or changed files and stale entries for deleted files, so git index hashes and `git status` views can mislead; `jj status` is the source of truth for file state
          * Working-copy renames are detected per file at ≥50% content similarity and are not configurable; a move with heavy edits shows as add+delete, and `jj file annotate` does not follow renames

          ## Inspect before writing

          HARD GATE: Before every write (`commit`, `new`, `describe`, `squash`, `split`, `edit`, `abandon`, `restore`, `rebase`, or resolving files), run `jj ls` in a separate tool call. Read all output; never pipe it through `head` or another truncating command.

          The workspace shown for `@` must match any `JJ workspace: <name>` in the current version control context. A mismatch is Unexpected: STOP and ask.
          `jj ls` is AP's alias for `jj log --limit 5` followed by `jj status`. It verifies the nearby graph and working-copy state, not complete history.

          * Expected: clean working copy or only changes made in this session
          * Shifted: graph moved after another operation, user action, or workspace update; understand it and adjust targets
          * Unexpected: unknown files, modifications, divergence, or conflicts outside an intentional conflict workflow; STOP and ask

          Use these read-only forms when `jj ls` is not enough:

          * Working-copy status: `jj status`
          * Current ancestry: `jj log -r '::@'`
          * Complete graph: `jj log -r 'all()'`
          * One change: `jj show <rev>`
          * Change evolution: `jj evolog -r <rev>`
          * Current diff: `jj diff --git` (`--stat`, `--summary`, or `--name-only` when appropriate)
          * Two endpoints: `jj diff --from <A> --to <B> --git <paths...>`
          * File at a revision: `jj file show -r <rev> <path>`

          ## Revisions, revsets, and templates

          Revsets select revisions, templates format output, and filesets select paths. Their functions are different languages; do not copy syntax between them.

          Common revsets:

          * `conflicts()` - conflicted changes
          * `description(glob:'text')` - description glob
          * `<rev>::@` - descendants from a revision through `@`
          * `ancestors(<rev>, <depth>)` - bounded ancestry
          * `trunk()`, `bookmarks()`, `all()` - repository sets
          * AP aliases: `private()`, `agent()`, `proj()`, `recent()`

          Template example: `jj log -r <revset> -T 'change_id.shortest() ++ " " ++ description.first_line() ++ "\n"'`. Template output is suitable for display; use full `change_id` when saving a target for later writes.

          Jujutsu is not git syntax:

          * Use `jj diff --from A --to B`, not `jj diff -r 'A..B'`
          * Use `parents(x)` or known forms such as `@-`, not postfix `x^`
          * Remote bookmarks are `name@remote`, not `remote/name`
          * `jj diff` has no `--check` or `--name-status`; use project checks and `--summary` or `--name-only`
          * `jj log` has no git `-S` pickaxe or `-f` follow flag: narrow with path arguments (`jj log <paths...>` shows the revisions that modified them); for history across a rename, pass both the old and new paths
          * jj revsets (`@`, `@-`) are not valid git arguments; when a read-only `git` query needs a revision, take the git hash printed next to each change id in `jj ls` output

          After any unknown command, option, revset, template, or fileset error, stop guessing and read version-matched help: `jj help <command>`, `jj <command> --help`, or `jj help -k revsets|templates|filesets|bookmarks|config|glossary`.

          ## Shape changes

          * Finalize current changes and create a new empty `@`: `jj commit -m "private: agent: <type>(<area>): description"`
          * Finalize selected files; the remaining files move to the new `@`: `jj commit -m "private: agent: <type>(<area>): description" <files...>`
          * Create a child of the current or named revision: `jj new [<rev>] -m "private: agent: <type>(<area>): description"`
          * Describe the current change: `jj describe -m "private: agent: <type>(<area>): description"`
          * Move current content into its parent, keeping the parent's message: `jj squash -u [<files...>]`
          * Move current content into its parent and replace the parent's message: `jj squash -m "private: agent: <type>(<area>): description" [<files...>]`
          * Split selected files into the original change: `jj split -m "private: agent: <type>(<area>): description" <files...>`
          * Path arguments to `jj commit <paths>` and `jj split <paths>` are literal filesets, not rename-aware: pass both the old and new paths to include a rename

          For `jj split`, selected files remain in the original change and `-m` describes that selected/original side. Never run bare `jj split`, `-i`, or an unspecified merge tool in an agent shell; they are interactive.

          Before starting a work unit:

          * Empty `@` -> `jj describe -m "private: agent: <type>(<area>): description"`
          * `@` has content -> `jj new -m "private: agent: <type>(<area>): description"`

          `jj restore <paths...>` restores paths in `@` from its parents. `jj restore` without paths restores the whole working-copy change from its parents but keeps the now-empty change and its description. `jj restore -c <rev>` reverses the changes introduced by a revision.

          ## Recipes

          * Move a file path in the working copy: plain `mv <old> <new>` (no jj command exists for this); the next `jj` command snapshots the move
          * Move file content from one change into another: `jj squash --from <A> --into <B> <paths...>`; an emptied source change is abandoned automatically
          * Modify an existing change without `jj edit`: `jj new <rev>`, make the change, then `jj squash -u`; use `jj edit <rev>` only when its direct behavior is intended (it replaces the whole working tree and can abandon the previous empty `@`) and the target is conflict-free
          * Resolve a conflicted revision: in a child created by `jj new <change_id>`, resolve the markers, inspect with `jj diff`, then `jj squash -u`; never `jj edit` the conflicted revision
          * Rollback and consolidate: create rollback points before implementation, refactoring, or review fixes; at completion, consolidate only `private: agent:` changes created in this session (normally one change for ad-hoc work or one per phase). Project documents kept in this repository should travel with the work change they document
          * Docs recipe (project documents in this repository): move the document paths from `@` into the full change ID of the work change they document with `jj squash --from @ --into <change_id> <doc paths...>`. Path-limited, so unrelated working changes stay in `@`. Nothing to do when `@` already is that change. This is a non-parent squash: apply the destructive-target inspection under Safety first, and skip it (mention that) when the target is immutable or not an agent change of this session

          ## Semantic commit messages

          Every agent change description is a semantic commit message (conventional commits): the `private: agent: ` prefix, then `<type>(<area>): <short imperative>`, e.g. `private: agent: feat(instr): add jj workspace rule`, `private: agent: fix(pi): bump mcp adapter`, `private: agent: chore(deps): bump flake lock`. Format follows the Conventional Commits spec (https://www.conventionalcommits.org/).

          * `<type>` is the conventional commit type: `build`, `chore`, `docs`, `feat`, `fix`, `perf`, `refactor`
          * `<area>` is the conventional scope: a lowercase tag for the subsystem the change touches. Check jj log for examples. Optional per the format, but include it when the change maps to one clear area.
          * Keep the description imperative and near 10 words
          * The `private: agent: ` prefix is what keeps the change unpushed (`private()`) and selectable (`agent()`); never drop it. This applies to every agent change, scratch and final

          ## AP helpers

          These are standalone shell commands, not `jj` subcommands; never write `jj diff-working`:

          * Work since closest bookmark or trunk, including private changes: `jj-diff-working --git` (`--stat` for files)
          * Current branch against the previous stacked bookmark: `jj-diff-branch --git`
          * Current, main, or previous branch name: `jj-current-branch`, `jj-main-branch`, `jj-prev-branch`

          For `gh`, use `$(jj-current-branch)` because git is detached.

          ## Conflicts

          Conflicts are stored in commits, propagate through descendants, and materialize as markers when checked out. `jj log` marks conflicted changes with `(conflict)`.

          * All conflicted changes: `jj log -r 'conflicts()'`
          * Paths conflicted in one revision: `jj resolve --list -r <change_id>`
          * `jj resolve --list` defaults to `@` and exits non-zero with `No conflicts found` when clean; do not put it before required commands in an `&&` chain
          * Plain `jj resolve` invokes a merge tool. Unless a tool is explicitly configured and approved, edit markers manually

          For stacked conflicts, use ${scope.commands."jj-resolve-conflicts".reference}.

          ## Safety

          Follow the `## Semantic commit messages` convention for every description. Never let a message editor open: pass `-m` when assigning a description, or `-u` when squashing while keeping the destination message. Undescribed scratch children such as conflict-resolution changes may use `jj new <rev>`.

          Never use `git stash`; use a new Jujutsu change. Never squash, abandon, reorder, or restore changes owned by the user or another agent.

          Before `jj abandon`, whole-change `jj restore`, `jj squash --into <non-parent>`, or `jj rebase -r`, inspect the exact full change ID with both `jj log -r <change_id> -T 'empty ++ "\n"'` and `jj diff --stat -r <change_id>`. Continue only when the observed content and target match the intended operation.

          * `jj abandon` removes a change and reparents descendants
          * Whole-change `jj restore` removes its content while preserving an empty revision
          * `jj squash --into <non-parent>` relocates content and can conflict while descendants are rebased
          * `jj rebase -r` moves only selected revisions; descendants remain at the old location and lose the selected revisions' contribution
          * After every graph write, re-read the graph before choosing another target; never use `@--` or deeper relative revisions for writes

          If a destructive target has content or its ownership is uncertain, STOP and ask.

          ## Recovery

          If an operation has an unexpected effect, STOP and report before recovery.

          * `jj undo` walks one operation backward and can be repeated; `jj redo` walks forward
          * `jj op log` lists operation IDs
          * `jj op show <op_id>` and `jj op diff <op_id>` inspect an operation
          * `jj --at-op <op_id> log` inspects repository state at that operation without restoring it
          * `jj op restore <op_id>` restores the repository to that operation

          For multi-step recovery, inspect with `jj op log` and `jj --at-op` first, then use one `jj op restore` only after approval.
        '';
      };
    files = { };
  };
}
