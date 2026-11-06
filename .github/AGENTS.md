# GitHub Actions

Workflows set up Nix through the repo-local composite action `./.github/actions/nix-setup`, which owns the installer
version, the `GH_PAT` access token, the substituters list and the trusted public keys. Pass its `packages`, `channel` or
`extra-features` inputs instead of writing installer steps; `action.yml` documents each input.
Build jobs pass `cache: true`, which caches build results with hestia; leave it off elsewhere, since substituting and
`nix eval` never reach hestia's post-build hook. The weekly `cache-gc` workflow deletes entries no branch uses.
