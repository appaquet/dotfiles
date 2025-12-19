# Instruction Restructure

Migrate from `docs/` with explicit `@` imports to `rules/` with auto-loading.

## Context

Current structure uses `docs/` folder with explicit `@docs/` references in CLAUDE.md. New Claude Code
feature supports `.claude/rules/` for auto-loaded instruction files.

**Current:**
```
claude/
├── CLAUDE.md           # References @docs/*
├── docs/
│   ├── version-control.md
│   ├── development.md
│   ├── code-style.md
│   └── project-doc.md
```

**Target:**
```
claude/
├── CLAUDE.md           # Simplified, no @docs/ references
├── rules/
│   ├── version-control.md
│   ├── development.md
│   ├── code-style.md
│   ├── project-doc.md
│   └── path-specific/
│       └── _example-rust.md  # Placeholder showing path rules
```

## Requirements

- Auto-load all instruction files via `rules/` directory
- Remove `docs/` folder entirely (all content moves to rules/)
- Add path-specific rules placeholder for future use
- Update nix config: remove `docs` symlink, add `rules` symlink
- Remove all `@docs/` references from CLAUDE.md and commands

## Files

- **CLAUDE.md**: Remove "Documentation References" section + @docs/project-doc.md ref in Context & Planning
- **docs/**: Delete folder after moving contents
- **rules/version-control.md**: Moved from docs/
- **rules/development.md**: Moved from docs/, remove @docs/version-control.md internal ref
- **rules/code-style.md**: Moved from docs/
- **rules/project-doc.md**: Moved from docs/
- **rules/path-specific/_example-rust.md**: Placeholder with paths: frontmatter
- **default.nix**: Remove "docs", add "rules" to symlink list
- **commands/ctx-save.md**: Remove @docs/project-doc.md references
- **commands/ctx-plan.md**: Remove @docs/project-doc.md references
- **commands/proj-init.md**: Remove @docs/project-doc.md references

## TODO

- [ ] Create `rules/` directory and `rules/path-specific/` subdirectory
- [ ] Move all docs/*.md files to rules/
- [ ] Remove @docs/ references within moved files (development.md → version-control.md)
- [ ] Create path-specific placeholder (rules/path-specific/_example-rust.md)
- [ ] Update default.nix: remove "docs", add "rules"
- [ ] Remove "Documentation References" section from CLAUDE.md
- [ ] Remove @docs/project-doc.md ref from CLAUDE.md Context & Planning section
- [ ] Remove @docs/project-doc.md references from commands (ctx-save, ctx-plan, proj-init)
- [ ] Delete empty docs/ folder
- [ ] Test: rebuild home-manager and verify rules load
