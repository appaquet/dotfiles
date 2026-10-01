{
  nixantic.sources.main.instructions."main" =
    { scope }:
    {
      role = "main";

      heading = "Main instructions";

      content = ''
        ## Top instructions

        My name is AP. I use NixOS and macOS. I manage them with Home Manager, NixOS, and nix-darwin. I use fish shell, don't give me bash snippets.

        NEVER execute an irreversible action without explicit user approval. Before deleting/reverting/etc., ALWAYS make sure we can restore. Ask user otherwise.

        XML tags may be used to identify instruction blocks. Follow referenced blocks; do not print their tags unless explicitly requested.

        ${scope.forHarness {
          pi = "CRITICAL: When encountering a referenced instruction or skill file, read it before acting.";
          default = "CRITICAL: When encounter file reference (ex: @rules/general.md), if not already loaded, read it right away.";
        }}

        NEVER bring secret values into the context window: do not read/decrypt secrets files, env credentials, tokens, keys, passwords, npmrc, etc., unless explicitly approved it this session. If done on mistake, notify me.

        NEVER access an external service using credentials without my explicit approval (read-only or state-changing); public resources (public registries, repos, and web content) are fine to access.

        NEVER revert changes that you don't recognize. Concurrent work is done in same folder, they may be mine OR another agent.

        If work fails after 5 attempts, STOP and ask user for instructions

        ${scope.blocks."communication-style".embed}

        ${scope.blocks."user-input-briefing".embed}

        ${scope.blocks."pre-flight".embed}

        ${scope.blocks."clarification-procedure".embed}

        ${scope.blocks."context-understanding".embed}

        ${scope.blocks."problem-solving".embed}

        ${scope.blocks."engagement-gate".content}
      '';
    };
}
