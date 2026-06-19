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

          - Main instruction files (CLAUDE.md, AGENTS.md, rules/*, etc.): automatically loaded by agentic harnesses, at start or directory based. Expect in opencode config, should always be CLAUDE.md to make sure all harnesses load them.
          - Commands: invoked by user. Claude can also invoke them.
          - Skills: loaded by LLMs based on user instructions or when think that they could be useful for their task. In Claude, skills=commands. Opencode, skills are dictincts.
          - Agents: instructions for sub-agents that can be spawned by harnesses. In opencode, can also describe instructions for main agents.
          - Blocks: own nixantic construct. Allow reusable instruction snippets and references. Can be embedded, but also referenced. Can be rendered as XML blocks, and then referred to with those (see tag)

          ## Instructions locations

          Project/directory specific instructions: CLAUDE.md, AGENTS.md, .opencode/AGENTS.md

          User instructions / commands / agents:
          - Don't try to edit ~/.claude or ~/.config/opencode directly, as they are rendered version of instructions in my dotfiles
          - All instructions in ~/dotfiles/home-manager/modules/agentic/instructions/
          - Rendering driven by `nixantic` component that lives in `~/dotfiles/nixantic`
          - You MUST read both CLAUDE.md to understand structure:
            - ~/dotfiles/nixantic/CLAUDE.md for renderer and reusable instruction patterns
            - ~/dotfiles/home-manager/modules/agentic/CLAUDE.md for my setup specific instructions
          - In ~/dotfiles/home-manager/modules/agentic/instructions, folders are organization feature, not actually rendered. Nix files define fragments.
          - Commands/skills or sub-directory instruction files should not needlessy repeat information in more global instruction files.

          ## Instructions principles

          - Instructions should be for steering and routing, no duplication information from code. Code is source of truth, while instructions/docs can easily rot as they aren't compiled/refactored as easily.
          - When steering, prefer mentioning what to do and reason to do so, instead of what not to do. What not to do can help on repeated failures.
          - Instructions must be clear, unambiguous, complete and imperative.
          - Instructions must be concise, avoid repetitions as they consume context tokens. You need to sacrifice style/syntax/proze for brevity.
          - Repetitions must be avoided across instructions. Do reconnaisance first. Propose or use reusable blocks.
          - Checklists should be block rendered as xml tag for higher recall salience.
          - Empty lines are automatically removed by renderer, so you can use them for readability in source files. Avoid multi-lines wrapping as they consume uncessary tokens on indented lines.
          - When writing procedures with step by steps, push LLM to use ${
            scope.blocks."task-management".reference
          } methodology.

          ## Instructions writing

          - Which instruction to edit should be based on context. If not clear what/where to edit, STOP and ask user.
          - You may not be able to edit them directly either if you're in a sandbox. If that's the case, tell the userr and give a detailed description of changes that need to be done. User will ask an agent inside ~/dotfiles.
          - Load similar/surrounding instruction files for patterns.
          - Do reconnaissance, find edit locations and then propose edit plan to user.
          - If you spent too much time finding information about nixantic or dotfiles setup, propose changes to dotfiles CLAUDE.md's.
          - If user agrees, proceed with edits.
          - Regenerate instructions after edits using repo's check&build commands.
        '';
      };
  };
}
