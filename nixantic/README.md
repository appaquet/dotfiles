# Nixantic

Nixantic renders consumer-supplied Nix instruction fragments into Claude Code, OpenCode, and Pi configuration trees. It contains no instruction corpus, policy, runtime extensions, or personal configuration.

## Inputs and module APIs

```nix
{
  inputs.nixantic.url = "github:OWNER/nixantic";
  inputs.nixantic.inputs.nixpkgs.follows = "nixpkgs";
}
```

The flake exports these stable integration aliases:

- `nixanticModules.default` and `nixanticModules.core`
- `homeManagerModules.default` and `homeManagerModules.nixantic`
- `homeModules` as the Home Manager module alias
- `flakeModules.default` and `flakeModules.nixantic`

Evaluate the core module with sources supplied by the consumer:

```nix
{
  imports = [ inputs.nixantic.nixanticModules.core ];
  nixantic.sources.project.instructions.main = {
    role = "main";
    heading = "Project instructions";
    content = "Follow this project's conventions.";
  };
}
```

`nixantic.sourceRoots` discovers fragment trees and `nixantic.sources` accepts explicit owner-keyed declarations. The renderer supports source discovery, harness filters, block references, commands, agents, skills and subfiles, dual command/skill outputs, VCS settings, post-processing, and BOM output.

Use `nixantic.instructions.install.files` to map selected rendered files through Home Manager. Set `nixantic.instructions.wrappers.install = true` to install the generic Claude and OpenCode config-directory wrappers. Helper CLIs are explicit named packages: `agentic-proj-docs` and `agentic-proj-create-adhoc`.

The flake-parts module exposes one configured consumer package and check:

```nix
{
  imports = [ inputs.nixantic.flakeModules.default ];
  perSystem = { ... }: {
    nixantic.enable = true;
    nixantic.packageName = "project-instructions";
    nixantic.checkName = "project-instructions";
    nixantic.modules = [ { nixantic.sources.project = /* sources */; } ];
  };
}
```

## Development

Use `direnv allow` or `nix develop`, then run `just fmt` or `just check`. From the parent repository, `nix flake check path:./nixantic --show-trace` runs the standalone checks. These checks use consumer-supplied neutral sources; this flake does not provide a production instruction corpus.

Before publishing or extracting this flake into its own repository, choose a license. No license is selected here.
