# Pi runtime

Pi and its plugins run through the Node variant of the `llm-agents` Pi package in production because configured extensions use Node built-ins such as `node:sqlite`. Plugin unit tests run on **bun** (`bun:test`).

## Tests

Local Pi tests live beside their source under `plugins/*.test.ts` or `lib/*.test.ts` and use bun:

- Each source file has at most one colocated `<name>.test.ts`. Tests are unit-focused — verify extension and library logic against fakes (`mock.module`) with no heavy harness (no `node_modules`, no external Pi runtime, no SSE server, no `pi-subagents`). Real Pi and nono smoke coverage belongs in the agentic flake checks, not this colocated suite.
- `import { test, ... } from "bun:test"`.
- Bun ships in the default flake development shell. Use `just pi-test-one lib/fuzzy-selector.test.ts` for one file and `just pi-test` for the full suite. The full recipe uses `--isolate`: bun shares module and `mock.module` state across files within one invocation (unlike `node --test`, which isolates per process), so one file's mocks would otherwise leak into another.
- The Pi package only resolves from the nix-store, which bun does not see from this repo. Keep Pi imports type-only (`import type`), or stub the `@earendil-works/*` specifiers with `mock.module`; inline trivial Pi runtime helpers (agent dir, event guards) instead of importing them.

`bash-timeout.test.ts` is the lone `node:test` file.

## Extension loading and Home Manager wiring

- `plugins/default.nix` `files` entries install into the live agent dir `~/.pi/agent/` after `./x home build` + switch.
- Only files placed under `.pi/agent/extensions/` are discovered as extensions. Everything else (config JSONs, etc.) is inert data that extensions read.
- Discovery: every `.ts`/`.js` file directly in `extensions/` loads; subdirectories load only their `index.ts`/`index.js` or paths declared in a `package.json` `pi.extensions` manifest. Scanning recurses at most one level.
- Every discovered file must `export default function (pi) {}`. A file without a factory logs a non-fatal startup error (`Extension does not export a valid factory function: <path>`), not a crash.
- So: one extension = one file under `extensions/`, with an accompanying `*.test.ts`. Type-only Pi imports (the `mode-switch.ts` pattern) keep it unit-testable under bun.
- To drive a handler outside a Pi process: import the extension with bun (type-only Pi imports erase, or `mock.module` the Pi specifiers), set `PI_CODING_AGENT_DIR` to a scratch dir holding its config, and call the handlers with a fake `ExtensionAPI`.
