# GitHub Actions

Workflows set up Nix through the repo-local composite action `./.github/actions/nix-setup`, which owns the installer
version, the `GH_PAT` access token, the substituters list and the trusted public keys. Pass its `packages`, `channel` or
`extra-features` inputs instead of writing installer steps; `action.yml` documents each input.
Build jobs pass `cache: true`, adding a hestia step that caches build results in the GitHub Actions cache; enable it only in
jobs that build, since substituted paths and `nix eval` never reach its post-build hook. A weekly `cache-gc` workflow prunes.
