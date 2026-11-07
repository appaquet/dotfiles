# Agent publish contract

How the agent workflow runs (`pi-bump`, `nix-bump`, `pi-dotfiles`) publish their work. The prompts name this file
and defer the mechanics here; the CI agent reads only its prompt, so this is the shared home for instructions the
runs have in common.

* Publish with git and the `gh` CLI, which authenticate as the repo owner via `GH_TOKEN`. Do not use the action's
  `create_pull_request` or `update_pull_request` tools: they run as the Actions bot, whose push check comes back
  negative and whose fork fallback throws, because GitHub bots cannot own forks.
* Commit with an inline `user.name` / `user.email` if the checkout has no identity.
* Pull requests and agent-posted comments are authored by `appaquet`; the action's own report comment on steering
  runs stays `github-actions[bot]`.
* When the run's PR branch already exists, fetch it and start from it so earlier decisions survive; otherwise
  create the branch from `master`. Pushing to the branch updates the existing PR; refresh its body with `gh pr
  edit` when the change set changes.
* If there is nothing worth publishing, change nothing and explain why in the run's report — never open an empty PR.
