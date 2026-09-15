{
  nixantic.sources.harnesses.skills."pi-nix-config" = {
    kind = "directory";
    main = {
      description = "To be used to personalize Pi on AP's personal setup. Covers the `~/.pi/` directory: how its configuration is nix-managed, where the nix sources live, how the mutable runtime settings.json merges with nix-owned values, and where to manage extension config files";
      content = ''
        # Pi Configuration

        `~/.pi/` is nix-managed territory: prefer declarative changes in dotfiles over direct writes.
        Direct writes are for session-scoped runtime state, or when AP explicitly asks for them.

        Pi's `~/.pi/agent/settings.json` is a mutable runtime file. Nix-owned defaults are merged into it at launch by the pi wrapper (nix values win).

        All nix sources live under `~/dotfiles/`.

        ## Nix-owned settings

        For persistent or declarative pi settings changes, edit `dotfiles.pi.settings` in `~/dotfiles/home-manager/modules/agentic/pi/default.nix`. For changes that should survive reconfigures, prefer that over editing the rendered `settings.json` directly.

        ## Pi instructions

        Pi instructions (AGENTS.md, rules, skills, prompts, agents) are rendered by nixantic from `.nix` sources under `~/dotfiles/home-manager/modules/agentic/instructions/`. Edit the nix source, not the rendered artifacts. Read `~/dotfiles/home-manager/modules/agentic/CLAUDE.md` before editing instructions.

        ## Pi runtime

        Pi package, wrapper, models, and plugins are managed under `~/dotfiles/home-manager/modules/agentic/pi/`. Read `~/dotfiles/home-manager/modules/agentic/pi/CLAUDE.md` for extension loading and testing details.
      '';
    };
    files = { };
  };
}
