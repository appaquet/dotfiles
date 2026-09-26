{
  nixantic.sources.instruction-authoring.skills."mem-writing" = {
    kind = "directory";

    main = {
      description = "Guidelines for writing agentic coding instructions: CLAUDE.md/AGENTS.md, command, skill or agent files.";
      content = ''
        # Agentic Instruction Writing

        ## Context

        These guidelines cover skills, main and directory instructions, commands/prompts, agents, and reusable blocks. In AP's setup, harness means an agentic coding tool: Claude Code, OpenCode, or Pi.
        Personal instruction sources are Nix files, typically under **~/dotfiles/**; harness artifacts are rendered from them. Some instruction files are directly authored Markdown and are edited in place. Read the applicable repository authoring guidance to tell them apart and to find the validation commands. Ask AP if the authoritative source cannot be located.
        Source folders organize fragments and are not reflected in rendered output. The model sees delivered text, not Nix attributes, source folders, or block provenance. Judge structure and behavior in that delivered context.

        ## Instructions

        * Give the agent enough context to understand the task and know where to look, then clear instructions about what to accomplish and which boundaries to respect. Leave execution choices to the agent unless a specific procedure is necessary.
        * Write compact, direct, imperative instructions. Prefer what to do and why; use prohibitions for safety boundaries and concrete recurring failures. Specify ordered steps only when order matters. Remove redundant prose without dropping conditions, scope, or exceptions.
        * Keep structure simple and related guidance together. Use the relevant artifact section below; do not turn every concern into a separate top-level section or force every artifact into the same template.
        * Use `*` for ordinary unordered lists; keep `-` only in fenced or literal output templates. Never mix ordinary marker styles in one rendered file.
        * Use bullets for distinct points. Never lay out instructions as a table: binding column headers to values is harder for a model than reading a labelled bullet, so write each row as its own bullet with its labels inline.
        * Steer and route rather than duplicate facts owned by code or other documentation. Code is the source of truth, while instructions rot because nothing compiles or refactors them. Keep one authoritative location per policy, reference or embed it where needed, and check for repetition in delivered text, including when a command, skill, or sub-directory instruction file restates what a more global file owns.
        * Keep shared guidance model-neutral. Scope harness- or model-specific behavior explicitly; preserve AP's planning, safety, testing, and approval requirements.
        * Nixantic removes empty lines from rendered output. Use them for source readability; avoid wrapping instruction prose across indented source lines.

        ### Editing and reviewing instructions

        * Before editing, read surrounding instructions, identify the authoritative source and the intended behavioral change, and propose the smallest sufficient edit for approval. If it is unclear what or where to edit, STOP and ask.
        * Load similar or surrounding instruction files for patterns. Do reconnaissance to find edit locations before proposing a plan.
        * Preserve unrelated wording and local syntax/style.
        * If Nixantic or the dotfiles setup takes too long to locate, propose improving the authoritative `AGENTS.md` or `CLAUDE.md` guidance.
        * Edit authoritative sources, not rendered artifacts. If access prevents editing, report the limitation and describe the required changes.
        * After editing, regenerate with the repository's checks and build commands, then review the full task diff against the requirements and this skill. Read the complete affected model-visible context, including relevant references: check policy placement, duplication, scope, clarity, and instruction-versus-output ambiguity.
        * Fix in-scope findings and repeat the affected checks. Report issues that require a scope decision instead of silently expanding the work.
        * Report build and render checks separately from instruction-quality review. A passing build does not establish clear instructions.

        ### Harness surfaces

        * Repo-level content is the only authoring surface that differs by harness. Everything of AP's own is authored once as Nix sources under **~/dotfiles** and rendered for every harness, so never send an author to a rendered artifact path.
        * Repo instruction files are concatenated, never merged, and a file in a parent directory applies to every repo beneath it.
        * Prefer `CLAUDE.md` for a repo that serves several harnesses: Claude Code reads it directly, while OpenCode and Pi reach it only as a fallback behind `AGENTS.md`. Claude Code's `AGENTS.md` support is recent and unreliable without telemetry, so treat `AGENTS.md` as an alternative rather than the shared default.

        #### Claude Code

        * Repo instruction files: `CLAUDE.md` or `.claude/CLAUDE.md` for team content, `CLAUDE.local.md` for personal gitignored content, and `.claude/rules/*.md` with optional `paths:` scoping. `AGENTS.md` loads only when no `CLAUDE.md` exists in the working directory or any parent.
        * Repo artifacts: `.claude/commands/*.md` (legacy; prefer skills), `.claude/skills/<name>/SKILL.md`, `.claude/agents/*.md`.

        #### OpenCode

        * Repo instruction files: `AGENTS.md` in every directory from the working directory up to the worktree root, nearest first. A project `AGENTS.md` suppresses every `CLAUDE.md` in the tree.
        * Repo artifacts: `.opencode/commands/*.md` (a nested path becomes `/team/name`), `.opencode/skills/<name>/SKILL.md` (also reads `.claude/skills/` and `.agents/skills/`), `.opencode/agents/*.md`.

        #### Pi

        * Repo instruction files: one per directory, first match wins: `AGENTS.override.md`, `AGENTS.md`, `CLAUDE.md`. Every directory from the repo up to the filesystem root is read.
        * Repo artifacts: `.pi/prompts/*.md`, `.pi/skills/**/SKILL.md` plus `.agents/skills/`, and, from AP's extensions, `.pi/agents/*.md` and `.pi/rules/*.md`.

        ### Skills

        * Give each skill one coherent area of guidance and a concise description that makes its activation conditions clear. Skills generally explain how to work, rather than request a particular operation.
        * Use **Context → Instructions** as the default body structure. Context explains the purpose, relevant background, and where to look. Instructions give principles, constraints, and guidance grouped by topic. Include procedures only where needed; not every skill needs a start-to-finish workflow or a single execution outcome.
        * When a skill requests a specific operation, use the command structure below. Commands exported as skills retain their command structure; packaging alone does not determine structure.
        * Add subsections only when they help navigation. For skills covering several artifact types or independent cases, put shared guidance first and the relevant case-specific sections beneath it.
        * Keep related guidance together. Move independently relevant detail into supporting references only when useful, and state when to read them; do not split a skill merely to shorten it.

        ### Main and directory instructions

        * Put persistent policies and broadly relevant context here. Keep global rules global; directory instructions should add only local guidance, source boundaries, and relevant commands.
        * Route to task-specific skills or documentation rather than loading their full procedures unconditionally.

        ### Commands / prompts

        * Use **Goal → State (optional) → Instructions** as the default body structure. Start with a `Goal:` statement naming the requested operation and expected result. Use `## State` for relevant supplied or gathered context when needed, then `## Instructions` for the actions or stages.
        * Make inputs clear and reference applicable skills for how to perform the work rather than repeating their guidance.
        * Describe what each stage must achieve, not every tool call. Number stages when their order matters, and make required decision points, approval gates, and the stopping point explicit. Follow the shared task-management rules for task-tracked procedures.

        ### Agents

        * Define the role, responsibilities, scope, decision boundaries, and expected handoff. Make clear which work the agent may perform and when it should return a question to its caller.
        * Reference shared policies rather than repeating them. Include only role-specific context and instructions needed to perform the assignment.
        * Agents hold instructions for sub-agents that harnesses can spawn, and some harnesses also use them for main agents.

        ### Reusable blocks

        * Keep each block focused on one coherent policy or reusable instruction fragment. Reuse existing policy blocks before creating another owner for the same guidance.
        * Use XML-tagged blocks for reusable checklists and named references. Check that references resolve in the delivered context and that embedding does not introduce needless repetition.
        * Treat blocks as text composition, not runtime control flow. Source placement determines text placement, not execution timing.
      '';
    };
  };
}
