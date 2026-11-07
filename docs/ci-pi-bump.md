# Pi plugin bumper (GitHub Actions)

The [pi-bump workflow](../.github/workflows/pi-bump.yaml) runs the Pi npm plugin bump on a runner and lets the agent
drive it: it reads the [pi-plugin-bump skill](../.agents/skills/pi-plugin-bump/SKILL.md), decides what is worth bumping,
edits `home-manager/modules/agentic/pi/plugins/default.nix`, verifies the Home Manager evaluation, and opens or updates
the pull request itself.

The workflow only supplies a trigger, tokens, nix, and node. There is no separate verification pipeline: the skill's
steps and your review of the PR are the safety net.

## Triggers

| Trigger | When |
| --- | --- |
| `schedule` | Every 3 days at 06:40 America/Toronto (month days 1, 4, 7, …, 28 — a 4-day gap at month end) |
| `workflow_dispatch` | Manual, with an optional `extra_instruction` |
| `issue_comment` | A comment starting with `@pi-bump` on a PR, authored by `appaquet` |

Runs are serialized by `concurrency: group: pi-bump`.

## Secrets

| Secret | Use |
| --- | --- |
| `OPENCODE_API_KEY` | Model access (`opencode-go` / `deepseek-v4.1-flash`). Required |
| `GH_PAT` | nix `access-tokens` for private flake inputs, and git operations the agent performs |
| `GITHUB_TOKEN` | Implicit. The agent's pull requests and comments, so they are authored by `github-actions[bot]` |

## Steering a run

Comment on a PR starting with `@pi-bump`; the rest of the comment becomes that run's extra instruction.

| Comment | Effect |
| --- | --- |
| `@pi-bump` | Re-run the bump |
| `@pi-bump skip pi-web-access` | Hold a package back |
| `@pi-bump pi-web-access@0.44.0` | Pin a specific version |
| `@pi-bump explain` | Explain which packages were held back and why |

## Applying a merged bump

Run `./x home switch` in the checkout that holds the merged change, then restart pi.

## Notes

- The agent has the action's full tool set, including `create_pull_request` and `update_pull_request`. It is not
  sandboxed to one file; the prompt asks it to touch only the pins file, and the diff in the PR is what you check.
- Merged bumps do not need a follow-up PR for held-back packages: the next scheduled run picks them up once they are
  old enough.
