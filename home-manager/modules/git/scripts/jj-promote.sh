#!/usr/bin/env bash
#
# jj-promote: promote agent-authored jujutsu changes by stripping the
# `unreviewed: ` description prefix. Un-promoted work may still carry the previous
# `private: agent: ` / `private: claude: ` prefixes; those are recognized and
# stripped the same way.
#
# The prefix marks a change as pending review and promotion; after stripping,
# the change keeps its conventional-commit message and leaves the private()
# revset, becoming pushable.
# Descriptions that do not carry an agent prefix (proj symlink commits, human
# scratch, already-promoted changes) are never modified.
#
# Usage and options: `jj-promote --help`.

set -euo pipefail

dry_run=false
edit=false
revsets=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --edit) edit=true ;;
    -h|--help)
      cat <<'EOF'
jj-promote: promote agent-authored jujutsu changes by stripping the `unreviewed: `
description prefix while keeping the conventional-commit message.

The previous `private: agent: ` / `private: claude: ` prefixes are recognized too and
stripped the same way.

Usage: jj-promote [--dry-run] [--edit] [REVSET...]
  REVSET...  revisions to promote (default: agent changes on the current branch, trunk()..@)
  --dry-run  show what would change, modify nothing
  --edit     open the editor on each pre-filled new description before writing

Descriptions without an agent prefix (proj symlink commits, human scratch, already-promoted
changes) are reported as skipped and left untouched. Every write is a jujutsu operation, so
`jj undo` reverts a promotion.
EOF
      exit 0
      ;;
    -*)
      echo "jj-promote: unknown option '$1'" >&2
      exit 1
      ;;
    *) revsets+=("$1") ;;
  esac
  shift
done

if [ "${#revsets[@]}" -gt 0 ]; then
  target=$(IFS='|'; echo "${revsets[*]}")
else
  # The current branch line: reachable from @, not from trunk. @ itself is in range, so a
  # bare invoke right after reviewing the working change promotes it. Other private kinds
  # (proj, scratch) may fall in range but are skipped by the per-revision prefix rule.
  target='trunk()..@ & (description(glob:'"'"'unreviewed:*'"'"') | description(glob:'"'"'private: agent:*'"'"') | description(glob:'"'"'private: claude:*'"'"'))'
fi

promoted=0
skipped=0

records=$(mktemp)
trap 'rm -f "$records"' EXIT

# Resolve the revset eagerly so a bad expression fails loudly instead of inside a pipe.
# Records are NUL-separated so multiline descriptions survive; fields are tab-separated.
jj log --no-graph --ignore-working-copy -r "$target" \
  -T 'change_id ++ "\t" ++ description ++ "\0"' >"$records"

# classify <record> -> CLASSIFY_KIND (agent|prefix-only|none) and CLASSIFY_PREFIX
classify() {
  local desc=${1#*$'\t'}
  case "$desc" in
    unreviewed:*)
      CLASSIFY_KIND=agent
      CLASSIFY_PREFIX='unreviewed: '
      ;;
    private:\ agent:*)
      CLASSIFY_KIND=agent
      CLASSIFY_PREFIX='private: agent: '
      ;;
    private:\ claude:*)
      CLASSIFY_KIND=agent
      CLASSIFY_PREFIX='private: claude: '
      ;;
    *)
      CLASSIFY_KIND=none
      CLASSIFY_PREFIX=''
      ;;
  esac
  if [ -n "$CLASSIFY_PREFIX" ]; then
    # A description consisting of nothing but the prefix would be emptied by the strip
    rest=${desc#"$CLASSIFY_PREFIX"}
    if [ -z "${rest//[[:space:]]/}" ]; then
      CLASSIFY_KIND=prefix-only
    fi
  fi
}

# strip (or preview) each record
while IFS= read -r -d '' record; do
  cid=${record%%$'\t'*}
  desc=${record#*$'\t'}
  classify "$record"
  kind=$CLASSIFY_KIND
  prefix=$CLASSIFY_PREFIX

  first_line=${desc%%$'\n'*}

  if [ "$kind" = none ]; then
    printf 'skip  %s  %s\n' "${cid:0:12}" "$first_line"
    skipped=$((skipped + 1))
    continue
  fi

  if [ "$kind" = prefix-only ]; then
    printf 'skip  %s  description is only the %s prefix\n' "${cid:0:12}" "$prefix"
    skipped=$((skipped + 1))
    continue
  fi

  # Command substitution drops the trailing newline; jj re-adds description normalization.
  new_desc=$(printf '%s' "${desc#"$prefix"}")
  new_first_line=${new_desc%%$'\n'*}

  if [ "$dry_run" = true ]; then
    printf 'would promote  %s  %s  ->  %s\n' "${cid:0:12}" "$first_line" "$new_first_line"
    promoted=$((promoted + 1))
    continue
  fi

  if [ "$edit" = true ]; then
    jj describe --editor -r "$cid" -m "$new_desc" >/dev/null 2>&1
  else
    jj describe -r "$cid" -m "$new_desc" >/dev/null 2>&1
  fi
  printf 'promoted  %s  %s  ->  %s\n' "${cid:0:12}" "$first_line" "$new_first_line"
  promoted=$((promoted + 1))
done <"$records"

if [ "$dry_run" = true ]; then
  printf 'dry run: %d to promote, %d skipped\n' "$promoted" "$skipped"
else
  printf 'promoted %d, skipped %d\n' "$promoted" "$skipped"
fi
