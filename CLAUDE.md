
## Building & Testing

Use `./x` script for building and evaluating nix configurations:

- `./x nixos check` - Eval nixos config for current host
- `./x nixos build` - Build nixos config
- `./x home check` - Eval home-manager config
- `./x home build` - Build home-manager config
- `HOST=deskapp ./x nixos check` - Check specific host

For quick iteration, use `check` first (fast eval) before `build`.

## Documentation

docs/features is symlink to secrets repo docs

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

Use the `mem-edit` skill for any changes to commands, agents, skills, or instruction docs.

Commands and agents must be documented in `docs/claude.md` under Workflows or Agents sections.

