# Print the base of the current unreviewed stack: the last ancestor that is neither
# unreviewed work nor private scaffolding, or trunk() when the whole line is agent work.
# Prints nothing when no agent work is pending, so the caller reports it.

# Explicit globs, not the agent() alias: this must work without user-config revsets.
agent_globs="description(glob:'unreviewed:*') | description(glob:'private: agent:*') | description(glob:'private: claude:*')"

# Private changes (the proj link, scratch notes) are scaffolding, not review material. A
# private change parked above the unreviewed work would otherwise become the base and hide
# that work behind an empty diff; one parked below stays a valid base, so its scaffolding
# never leaks into the review diff.
private_globs="description(glob:'private:*')"

if [ -z "$(jj --ignore-working-copy log --no-graph -r "trunk()..@ & ($agent_globs)" -T 'change_id')" ]; then
  exit 0
fi

base=$(jj_commit_id "latest(heads(::@- & ~($agent_globs) & ~($private_globs & ($agent_globs)::)), 1)")

# The line is entirely agent work (or only the synthetic root remains): diff from trunk.
if [ -z "$base" ] || [[ "$base" =~ ^0{40}$ ]]; then
  base=$(jj_commit_id 'trunk()')
fi

if [ -z "$base" ]; then
  echo "Unable to resolve a base for the unreviewed stack diff." >&2
  exit 1
fi

printf '%s\n' "$base"
