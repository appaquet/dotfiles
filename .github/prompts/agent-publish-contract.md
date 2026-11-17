# Agent publish contract

How the agent workflow runs publish their work. The prompts name this file and defer the mechanics here; the CI agent reads only its prompt, so this is the shared home for instructions the runs have in common.

* Publish with git and the `gh` CLI. The default `GH_TOKEN` is the repo owner's token. Do not use the action's
  `create_pull_request` or `update_pull_request` tools: they run as the Actions bot, whose push check comes back
  negative and whose fork fallback throws, because GitHub bots cannot own forks.

* Commit with an inline `user.name` / `user.email` if the checkout has no identity.

* Open PRs and post agent comments as `appaquet` unless the workflow prompt specifies a different identity for
  opening a new PR. The bump workflows push with the owner's token, then open new PRs with the Actions bot token
  so they can request review from `appaquet`. The action's own report comment on steering runs stays
  `github-actions[bot]`.

* When the run's PR branch already exists, fetch it and start from it so earlier decisions survive; otherwise
  create the branch from `master`. Pushing to the branch updates the existing PR; refresh its body with `gh pr
  edit` when the change set changes.

* If there is nothing worth publishing, change nothing and explain why in the run's report — never open an empty PR.
