# Pi runtime

Pi runs on **node**, not bun. Do not reach for bun here.

## Tests

Local Pi plugin tests live under `plugins/*.test.ts` and use Node's built-in runner:

- `import { test, ... } from "node:test"` + `node:assert` (not `bun:test`).
- Run with `node --test <file>` from the `plugins/` directory.
- Keep any Pi import type-only (`import type`, erased at load) so the whole
  extension file loads under plain node. The Pi package only resolves from the
  nix-store, which plain node does not see from this repo; inline trivial Pi
  runtime helpers (agent dir, event guards) instead of importing them.

Example: `node --test bash-timeout.test.ts`.

## Extension loading and Home Manager wiring

- `plugins/default.nix` `files` entries install into the live agent dir `~/.pi/agent/` after `./x home build` + switch.
- Only files placed under `.pi/agent/extensions/` are discovered as extensions. Everything else (config JSONs, etc.) is inert data that extensions read.
- Discovery: every `.ts`/`.js` file directly in `extensions/` loads; subdirectories load only their `index.ts`/`index.js` or paths declared in a `package.json` `pi.extensions` manifest. Scanning recurses at most one level.
- Every discovered file must `export default function (pi) {}`. A file without a factory logs a non-fatal startup error (`Extension does not export a valid factory function: <path>`), not a crash.
- So: one extension = one file under `extensions/`, with an accompanying `*.test.ts`. Type-only Pi imports (the `mode-switch.ts` pattern) keep it unit-testable under plain node.
- To drive a handler outside a Pi process: import the extension with plain node (type-only Pi imports erase), set `PI_CODING_AGENT_DIR` to a scratch dir holding its config, and call the handlers with a fake `ExtensionAPI`.
