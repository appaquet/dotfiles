
## Building & Testing

Use `./x` script for building and evaluating nix configurations:

- `./x nixos check` - Eval nixos config for current host
- `./x nixos build` - Build nixos config
- `./x home check` - Eval home-manager config
- `./x home build` - Build home-manager config
- `HOST=deskapp ./x nixos check` - Check specific host

For quick iteration, use `check` first (fast eval) before `build`.

## Documentation

`docs/features/` is a symlink to a **separate secrets repo**. This means:

- Project docs (`proj/` → `docs/features/.../00-*.md`) are NOT in this repo
- Changes to project docs are tracked in the secrets repo, not here
- `jj status` in dotfiles will NOT show project doc changes
- Only commit dotfiles changes (commands, skills, etc.) in this repo

## Claude

Source: `home-manager/modules/claude/{..}` (symlinked to `~/.claude/{...}`).
Editing either location modifies the same files.

### Components

| Type | Location |
|------|----------|
| Main instructions | `CLAUDE.md` |
| Supporting docs | `docs/` |
| Commands | `commands/<name>.md` |
| Agents | `agents/<name>.md` |
| Settings | `settings.json` |

### Modifying Instructions

ALWAYS use the `/mem-edit` command for any changes to instruction files:

- Commands (`commands/*.md`)
- Skills (`skills/*/`)
- Agents (`agents/*.md`)
- Supporting docs (`docs/*.md`)
