---
name: github-fetch-bump
description: Audit and update fetchFromGitHub pins (rev + hash) in the dotfiles nix setup
---

# Bump fetchFromGitHub pins

Run from the worktree root. Scope: `fetchFromGitHub` only (not flake `github:` inputs, not other
fetchers). Audit every pin, show a table, then after confirmation update the chosen ones end-to-end.

## Audit

1. Find every `fetchFromGitHub` pin in the nix setup (`overlays/`, `home-manager/`), excluding build
   artifacts (`result/`, `.direnv/`). Note each pin's `owner`, `repo`, `rev`, and surrounding
   `version`.

2. Classify each pin:
   - `tag` — `rev` is a tag string (e.g. `v1.2.3`, or `"v${version}"`).
   - `rev` — `rev` is a raw 40-hex commit SHA.
   - `needs-review` — `rev` is a PR-head / non-ancestor SHA (a comment or CHANGELOG hints it), e.g.
     jj built from an unmerged PR.

3. Per fetch, look up on GitHub (`gh` is authenticated): the default-branch head (sha + committer
date), the latest release (tag + date; may not exist), and the commit delta from the pinned rev to
the proposed target (ahead-by count + ahead/behind/diverged).

4. Proposed new pin — match the current pin type: `tag` → latest release tag; `rev` → latest
branch-head SHA. Always show the latest-rev committer date (even for a tag) so AP can override.

5. Change summary: the ahead-by commit count + a 1-2 line headline from the commit range / release
notes. Deep-dive (read CHANGELOG / PR / release notes, or spawn a sub-agent) only when the pin is
non-standard or the delta looks risky.

6. Present one table: `fetch (file) | current | proposed-new | latest-rev date | status | change
summary`, status ∈ `up-to-date` / `bumpable` / `needs-review`.

## Confirm

1. List `needs-review` rows separately with a one-line reason; do not offer to bump them.

2. Stop and await AP's instruction on which `bumpable` fetches to apply — do not use
   `ask_user_question`; AP follows up with the choice. The Apply steps below run only on the
   fetches AP names.

## Apply (per selected fetch)

1. Get the real hash for the new rev without a full `home build`. `fetchFromGitHub`'s tarball hash
is arch-independent, so a scoped build works: build just the fetch with a dummy hash and read the
real value from the `got:    sha256-…` line in the error (note the multiple spaces after `got:`):
`nix build --impure --expr "(import <nixpkgs> {}).fetchFromGitHub { owner = \"<o>\"; repo = \"<r>\";
rev = \"<new-rev>\"; hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"; }"`

2. Edit the nix file: set `rev`; set `version` (first 12 chars for a SHA pin, keep the tag string
for a tag pin); set `hash`/`sha256`; update any stale commit-tree comment to the new rev. Then `./x
fmt`.

3. Verify the affected package builds from the edited on-disk file. Build the specific attr with a
direct `import ./path` of the overlay/file that wraps the fetch (reads the uncommitted edit — the
flake ref reads git HEAD in this worktree). This catches `sourceRoot`/`postPatch` failures. Skip
this build for darwin-only packages on Linux (hash + eval suffice).

4. Commit with jj per the version-control workflow: one commit for the bump, prefix `private:
agent:`.

5. Final eval after the commit (the flake ref now sees the change): `HOST=deskapp ./x home check`.
