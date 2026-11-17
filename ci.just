# GitHub Actions workflow lockfile (.github/workflows/actions.lock), driven by the gh-actions-lock extension.
# Install it once with: gh extension install github/gh-actions-lock

# Lint the GitHub workflows with actionlint, without changing files. Shellcheck of `run:` scripts is off so local and CI results match.
lint:
    actionlint -shellcheck=

# Lock every `uses:` and rewrite the lockfile; pass flags through, e.g. `just ci::lock --relock`.
lock *args:
    gh actions-lock {{ args }}

# Check the lockfile matches the workflows and every pin still verifies upstream (what CI runs). Writes nothing.
lock-verify:
    gh actions-lock --verify
