{
  nixantic.sources.instruction-authoring.skills."mem-writing" = {
    kind = "directory";

    main =
      { scope }:
      {
        description = "Guidelines for writing agentic coding instructions: CLAUDE.md/AGENTS.md, command, skill or agent files.";
        content = ''
          # Agentic Instruction Writing

          Lingua: harness = agentic coding = claude code / opencode / pi

          ## Instructions kinds

          ${scope.forHarness {
            pi = "- Main instruction files: `AGENTS.md` is active context; aggregated rules belong in it.";
            default = "- Main instruction files (CLAUDE.md, AGENTS.md, rules/*, etc.): automatically loaded by agentic harnesses, at start or directory based. Expect in opencode config, should always be CLAUDE.md to make sure all harnesses load them.";
          }}
          ${scope.forHarness {
            pi = "- Prompts: user-invoked Markdown prompt templates under `prompts/`.";
            default = "- Commands: invoked by user. Claude can also invoke them.";
          }}
          ${scope.forHarness {
            pi = "- Skills: Agent Skills under `skills/<name>/SKILL.md`, loaded on demand from their descriptions.";
            default = "- Skills: loaded by LLMs based on user instructions or when think that they could be useful for their task. In Claude, skills=commands. Opencode, skills are distinct.";
          }}
          ${scope.forHarness {
            pi = "- Agents: adapter-defined files under `agents/`; consumers map them to configured Pi agent locations.";
            default = "- Agents: instructions for sub-agents that can be spawned by harnesses. In opencode, can also describe instructions for main agents.";
          }}
          - Blocks: own nixantic construct. Allow reusable instruction snippets and references. Can be embedded, but also referenced. Can be rendered as XML blocks, and then referred to with those (see tag)

          ## Instructions locations

          ${scope.forHarness {
            pi = "Project/directory specific instructions: `AGENTS.md`; skill directories use `SKILL.md`.";
            default = "Project/directory specific instructions: CLAUDE.md, AGENTS.md, .opencode/AGENTS.md";
          }}

          User instructions / commands / agents:
          ${scope.forHarness {
            pi = "- Do not edit rendered Pi artifacts directly; edit the Nix instruction source.";
            default = "- Don't try to edit ~/.claude or ~/.config/opencode directly, as they are rendered versions of instruction source files.";
          }}
          - Instruction sources are `.nix` files, typically under **~/dotfiles/**.
          - If you cannot locate them, **ask the user** where their instruction source files are.
          - Folders are an organization feature, not directly reflected in rendered output. Nix files define fragments.
          - Commands/skills or sub-directory instruction files should not needlessly repeat information in more global instruction files.

          ## Instructions principles

          - Instructions should be for steering and routing, no duplication information from code. Code is source of truth, while instructions/docs can easily rot as they aren't compiled/refactored as easily.
          - When steering, prefer mentioning what to do and reason to do so, instead of what not to do. What not to do can help on repeated failures.
          - Instructions must be clear, unambiguous, complete and imperative.
          - For style, follow the global telegraphic-style rule.
          - When editing instructions: preserve local syntax/style, change only requested wording; no surrounding fluency rewrites.
          - One authoritative location per policy; reference/embed elsewhere. Do reconnaissance first, propose or use reusable blocks.
          - Checklists should be block rendered as xml tag for higher recall salience.
          - Empty lines are automatically removed by renderer, so you can use them for readability in source files. Avoid multi-lines wrapping as they consume unnecessary tokens on indented lines.
          - When writing procedures with step by steps, push LLM to use ${
            scope.blocks."task-management".reference
          } methodology.

          ## Instructions writing

          - Before edit: identify authoritative source and smallest sufficient diff.
          - Which instruction to edit should be based on context. If not clear what/where to edit, STOP and ask user.
          - You may not be able to edit them directly either if you're in a sandbox. If that's the case, tell the user and give a detailed description of changes that need to be done.
          - Load similar/surrounding instruction files for patterns.
          - Do reconnaissance, find edit locations and then propose edit plan to user.
          ${scope.forHarness {
            pi = "- If Nixantic or dotfiles setup takes too long to locate, propose improving the authoritative `AGENTS.md` guidance.";
            default = "- If you spent too much time finding information about nixantic or dotfiles setup, propose changes to dotfiles CLAUDE.md's.";
          }}
          - If user agrees, proceed with edits.
          - After edit: diff-review added prose, duplicated policy, unnecessary rewording, scope expansion; remove before finish.
          - Regenerate instructions after edits using repo's check&build commands.
        '';
      };
  };
}
