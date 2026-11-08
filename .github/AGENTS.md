# GitHub Actions

Workflows set up Nix through the repo-local composite action `./.github/actions/nix-setup`, which owns the installer
version, the `GH_PAT` access token, the substituters list and the trusted public keys. Pass its `packages`, `channel` or
`extra-features` inputs instead of writing installer steps; `action.yml` documents each input.
Build jobs pass `cache: true`, which caches build results with hestia; leave it off elsewhere, since substituting and
`nix eval` never reach hestia's post-build hook. Nothing prunes that cache: GitHub evicts least-recently-used entries.

The agent workflows (`pi-bump`, `nix-bump`, `pi-dotfiles`) are siblings: each checks out the repo first, then shares
`./.github/actions/pi-agent` (nix, optional node, pinned agent invocation), and every prompt defers the PR mechanics to
`.github/prompts/agent-publish-contract.md`. The CI agent only reads its prompt — this file guides the agent that
maintains the workflows, not the agent that runs them. Check the siblings together: a change that fixes one
workflow usually applies to the others, and a change to the shared action or the contract must be reviewed against
every consuming workflow in the same change.

Dependabot (`.github/dependabot.yml`) bumps the action pins weekly as one grouped PR. Its second `directories` entry is what
keeps the pins in `.github/actions/nix-setup` in scope; dropping it leaves that composite action unmanaged. Flake inputs are
not Dependabot's: the "Flake updater" workflow owns `flake.lock`.
