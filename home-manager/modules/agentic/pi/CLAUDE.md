# Pi runtime

Pi and its plugins run through the Node variant of the `llm-agents` Pi package in production because configured extensions use Node built-ins such as `node:sqlite`. Plugin unit tests run on **bun** (`bun:test`).

## Tests

Local Pi tests live beside their source under `plugins/*.test.ts` or `lib/*.test.ts` and use bun:

- Each source file has at most one colocated `<name>.test.ts`. Tests are unit-focused — verify extension and library logic against fakes (`mock.module`) with no heavy harness (no `node_modules`, no external Pi runtime, no SSE server, no `pi-subagents`). Real Pi and nono smoke coverage belongs in the agentic flake checks, not this colocated suite.
- `import { test, ... } from "bun:test"`.
- Bun ships in the default flake development shell. Run the suite with `just test pi-plugins-unit`, which runs it in the sandbox and sets `NODE_PATH` for the two TUI-dependent files. A direct run is `bun test --isolate plugins/*.test.ts lib/*.test.ts`, which needs `NODE_PATH` pointing at Pi's bundled `node_modules`. The `--isolate` flag matters: bun shares module and `mock.module` state across files within one invocation (unlike `node --test`, which isolates per process), so one file's mocks would otherwise leak into another.
- The Pi package only resolves from the nix-store, which bun does not see from this repo. Keep Pi imports type-only (`import type`), or stub the `@earendil-works/*` specifiers with `mock.module`; inline trivial Pi runtime helpers (agent dir, event guards) instead of importing them.

`bash-timeout.test.ts` is the lone `node:test` file.

## Core MCP configuration

`mcp.nix` owns the global `~/.pi/agent/mcp.json`; it is core configuration, not plugin data. Keep global server definitions, enablement, and exposure declarative. Native `/mcp` can inspect and reconnect servers, but its persistent configuration edits and `pi mcp add/remove` cannot write the Home Manager store symlink. Trusted projects can override servers by name in their own `.pi/mcp.json`.

Chrome uses native `codemode` exposure, which activates codemode when the server connects without hiding ordinary tools. Discover tools with `searchTools()`/`describeTool()` and call `tools.mcp__chrome__<tool>()` in codemode scripts. MCP calls return `CallToolResult` (`content`, optional `structuredContent`, `isError`); use `text()` or `image()` to return selected output. Do not use adapter `mcp`/`mcpScript` gateway APIs.

After changing configured packages, activate Home Manager and start a fresh Pi process so the wrapper remerges settings. `/reload` refreshes resources and MCP configuration but does not rerun that wrapper merge. Unlisted npm packages are not loaded, even if cached install files remain.

## Extension loading and Home Manager wiring

- `plugins/default.nix` `files` entries install into the live agent dir `~/.pi/agent/` after `./x home build` + switch. Extension global config/state files live in the owning plugin's `files` attr there, not in the top-level `default.nix`.
- Only files placed under `.pi/agent/extensions/` are discovered as extensions. Everything else (config JSONs, etc.) is inert data that extensions read.
- Discovery: every `.ts`/`.js` file directly in `extensions/` loads; subdirectories load only their `index.ts`/`index.js` or paths declared in a `package.json` `pi.extensions` manifest. Scanning recurses at most one level.
- Every discovered file must `export default function (pi) {}`. A file without a factory logs a non-fatal startup error (`Extension does not export a valid factory function: <path>`), not a crash.
- So: one extension = one file under `extensions/`, with an accompanying `*.test.ts`. Type-only Pi imports (the `mode-switch.ts` pattern) keep it unit-testable under bun.
- To drive a handler outside a Pi process: import the extension with bun (type-only Pi imports erase, or `mock.module` the Pi specifiers), set `PI_CODING_AGENT_DIR` to a scratch dir holding its config, and call the handlers with a fake `ExtensionAPI`.
