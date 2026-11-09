#!/usr/bin/env bash
#
# Behavioral suite for the jj stack commands: jj-stacked-branches, jj-prev-branch,
# jj-main-branch, jj-diff-branch, and jj-stacked-stats.
#
# Two properties carry real regression risk and are covered here because neither is
# visible in a one-bookmark repo: the stack commands must survive a stack deep enough for
# a reader to close the pipe early, and bookmark names must be printed without the marker
# jj renders for a bookmark that diverges from its remote.
#
# Usage:
#   JJ_UTILS_BIN=/path/to/bin ./jj-stack-unit.sh
#
# JJ_UTILS_BIN must point at the bin directory holding the commands under test.

set -uo pipefail

if [ -z "${JJ_UTILS_BIN:-}" ]; then
  echo "FATAL: JJ_UTILS_BIN is not set; point it at the jj-utils bin directory" >&2
  exit 1
fi

command -v jj >/dev/null || { echo "FATAL: jj not on PATH" >&2; exit 1; }

PATH="$JJ_UTILS_BIN:$PATH"
export PATH

# Command output goes here, never inside a repo working copy: jj snapshots untracked
# files, and a later change rewrite would conflict on them.
out=$(mktemp -d)
# jj needs a writable HOME even for repo-level config (secure config lookup).
HOME="$out/home"
mkdir -p "$HOME"
export HOME
trap 'rm -rf "$out"' EXIT
failures=0
tests=0

pass() { printf 'ok   - %s\n' "$1"; }
fail() {
  failures=$((failures + 1))
  printf 'FAIL - %s\n' "$1" >&2
  if [ -n "${2:-}" ]; then printf '       %s\n' "$2" >&2; fi
}

# assert_eq <label> <expected> <actual>
assert_eq() {
  tests=$((tests + 1))
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "expected: [$2] / actual: [$3]"
  fi
}

# assert_true <label> <exit-code>
assert_true() {
  tests=$((tests + 1))
  if [ "$2" = "0" ]; then pass "$1"; else fail "$1" "command exited $2"; fi
}

# new_repo -> prints a fresh repo dir with a three-bookmark stack: main, feat-one, feat-two
new_repo() {
  local repo
  repo=$(mktemp -d) || return 1
  (
    cd "$repo" || exit 1
    jj git init >/dev/null || exit 1
    # Commits need an identity: the check sandbox has no user jj config.
    jj config set --repo user.name "Test User" >/dev/null || exit 1
    jj config set --repo user.email "test@example.com" >/dev/null || exit 1
    jj config set --repo 'revset-aliases."trunk()"' main >/dev/null || exit 1
    printf 'base\n' > file.txt
    jj commit -m base >/dev/null || exit 1
    jj bookmark create main -r @- >/dev/null || exit 1
    printf 'one\n' >> file.txt
    jj commit -m one >/dev/null || exit 1
    jj bookmark create feat-one -r @- >/dev/null || exit 1
    printf 'two\n' >> file.txt
    jj commit -m two >/dev/null || exit 1
    jj bookmark create feat-two -r @- >/dev/null || exit 1
  ) >&2 || return 1
  printf '%s\n' "$repo"
}

# new_review_repo <private-above|private-below|private-only> -> repo whose trunk is `main`,
# holding an unreviewed change and a private change in the requested order
new_review_repo() {
  local repo
  repo=$(mktemp -d) || return 1
  (
    cd "$repo" || exit 1
    jj git init >/dev/null || exit 1
    jj config set --repo user.name "Test User" >/dev/null || exit 1
    jj config set --repo user.email "test@example.com" >/dev/null || exit 1
    jj config set --repo 'revset-aliases."trunk()"' main >/dev/null || exit 1
    printf 'base\n' > base.txt
    jj commit -m 'chore: base' >/dev/null || exit 1
    jj bookmark create main -r @- >/dev/null || exit 1

    if [ "$1" != "private-below" ]; then
      if [ "$1" = "private-above" ]; then
        printf 'work\n' > work.txt
        jj commit -m 'unreviewed: feat(demo): review me' >/dev/null || exit 1
      fi

      printf 'link\n' > link.txt
      jj commit -m 'private: proj - demo' >/dev/null || exit 1
    else
      printf 'link\n' > link.txt
      jj commit -m 'private: proj - demo' >/dev/null || exit 1
      printf 'work\n' > work.txt
      jj commit -m 'unreviewed: feat(demo): review me' >/dev/null || exit 1
    fi
  ) >&2 || return 1
  printf '%s\n' "$repo"
}

echo "== jj-stack suite =="

repo=$(new_repo) || { echo "FATAL: repo setup failed" >&2; exit 1; }

# --- Case: the stack is listed oldest last, and the previous branch is the one below ---
( cd "$repo" && jj-stacked-branches ) >"$out/stack.log" 2>&1; rc=$?
assert_true "stacked-branches exits 0 on a three-bookmark stack" "$rc"
assert_eq "stacked-branches lists the stack newest first" \
  "feat-two
feat-one
main" "$(cat "$out/stack.log")"

( cd "$repo" && jj-prev-branch ) >"$out/prev.log" 2>&1; rc=$?
assert_true "prev-branch exits 0 on a three-bookmark stack" "$rc"
assert_eq "prev-branch prints the bookmark below the current work" "feat-one" "$(cat "$out/prev.log")"

( cd "$repo" && jj-main-branch ) >"$out/main.log" 2>&1; rc=$?
assert_true "main-branch exits 0" "$rc"
assert_eq "main-branch prints the trunk bookmark" "main" "$(cat "$out/main.log")"

# --- Case: diff-branch diffs against the previous bookmark, on a stack deep enough for a
# reader to close the pipe early -----------------------------------------------------
( cd "$repo" && jj-diff-branch --git ) >"$out/diffbranch.log" 2>&1; rc=$?
assert_true "diff-branch exits 0 on a three-bookmark stack" "$rc"
assert_eq "diff-branch shows the change above the previous bookmark and nothing older" \
  "+two" "$(grep -E '^\+[^+]' "$out/diffbranch.log" | tr '\n' ' ' | sed 's/ $//')"

( cd "$repo" && jj-stacked-stats ) >"$out/stats.log" 2>&1; rc=$?
assert_true "stacked-stats exits 0" "$rc"
grep -q 'Changes since trunk():' "$out/stats.log" \
  && pass "stacked-stats reports its starting revision" \
  || fail "stacked-stats reports its starting revision" "$(head -5 "$out/stats.log")"

# --- Case: a single-bookmark stack falls back to that bookmark ------------------------
single=$(mktemp -d) || { echo "FATAL: repo setup failed" >&2; exit 1; }
(
  cd "$single" || exit 1
  jj git init >/dev/null || exit 1
  jj config set --repo user.name "Test User" >/dev/null || exit 1
  jj config set --repo user.email "test@example.com" >/dev/null || exit 1
  jj config set --repo 'revset-aliases."trunk()"' main >/dev/null || exit 1
  printf 'base\n' > file.txt
  jj commit -m base >/dev/null || exit 1
  jj bookmark create main -r @- >/dev/null || exit 1
) >&2

( cd "$single" && jj-prev-branch ) >"$out/prev-single.log" 2>&1; rc=$?
assert_true "prev-branch exits 0 on a single-bookmark stack" "$rc"
assert_eq "prev-branch falls back to the only bookmark" "main" "$(cat "$out/prev-single.log")"
rm -rf "$single"

# --- Case: a bookmark diverged from its remote is printed without jj's marker --------
git init --bare "$out/upstream.git" >/dev/null 2>&1
( cd "$repo" && jj git remote add upstream "$out/upstream.git" >/dev/null 2>&1 )
( cd "$repo" && jj git push -b feat-two >/dev/null 2>&1 ); rc=$?
assert_true "publishing feat-two succeeds" "$rc"
( cd "$repo" && jj bookmark set feat-two -r @ >/dev/null 2>&1 ); rc=$?
assert_true "moving feat-two away from its remote succeeds" "$rc"

raw=$( cd "$repo" && jj log --no-graph -r 'bookmarks()' -T 'local_bookmarks ++ "\n"' )
assert_eq "the fixture really holds a diverged bookmark" "1" "$(printf '%s\n' "$raw" | grep -c 'feat-two\*')"

( cd "$repo" && jj-stacked-branches ) >"$out/stack-diverged.log" 2>&1; rc=$?
assert_true "stacked-branches exits 0 with a diverged bookmark" "$rc"
assert_eq "stacked-branches prints no display marker" "0" "$(grep -c '\*' "$out/stack-diverged.log")"

( cd "$repo" && jj config set --repo 'revset-aliases."trunk()"' feat-two >/dev/null 2>&1 )
( cd "$repo" && jj-main-branch ) >"$out/main-diverged.log" 2>&1; rc=$?
assert_true "main-branch exits 0 on a diverged trunk bookmark" "$rc"
assert_eq "main-branch prints the bare bookmark name" "feat-two" "$(cat "$out/main-diverged.log")"

# --- Case: private scaffolding above the unreviewed work is stepped over --------------
above=$(new_review_repo private-above) || { echo "FATAL: repo setup failed" >&2; exit 1; }
trunk_id=$( cd "$above" && jj log --no-graph -r 'trunk()' -T 'commit_id' )
base=$( cd "$above" && jj-unreviewed-base ); rc=$?
assert_true "unreviewed-base exits 0 with scaffolding above the work" "$rc"
assert_eq "unreviewed-base steps over private scaffolding above the work" "$trunk_id" "$base"

( cd "$above" && jj-diff-unreviewed --stat ) >"$out/unrev-above.log" 2>&1; rc=$?
assert_true "diff-unreviewed exits 0 with scaffolding above the work" "$rc"
grep -q 'work.txt' "$out/unrev-above.log" \
  && pass "diff-unreviewed shows the work below the scaffolding" \
  || fail "diff-unreviewed shows the work below the scaffolding" "$(cat "$out/unrev-above.log")"
rm -rf "$above"

# --- Case: private scaffolding below the unreviewed work stays the base --------------
below=$(new_review_repo private-below) || { echo "FATAL: repo setup failed" >&2; exit 1; }
private_id=$( cd "$below" && jj log --no-graph -r "description(glob:'private:*')" -T 'commit_id' )
base=$( cd "$below" && jj-unreviewed-base ); rc=$?
assert_true "unreviewed-base exits 0 with scaffolding below the work" "$rc"
assert_eq "unreviewed-base keeps scaffolding below the work as the base" "$private_id" "$base"

( cd "$below" && jj-diff-unreviewed --stat ) >"$out/unrev-below.log" 2>&1; rc=$?
assert_true "diff-unreviewed exits 0 with scaffolding below the work" "$rc"
assert_eq "diff-unreviewed keeps scaffolding below the work out of the diff" \
  "0" "$(grep -c 'link.txt' "$out/unrev-below.log")"
rm -rf "$below"

# --- Case: no unreviewed work on the line --------------------------------------------
quiet=$(new_review_repo private-only) || { echo "FATAL: repo setup failed" >&2; exit 1; }
( cd "$quiet" && jj-unreviewed-base ) >"$out/unrev-none.log" 2>&1; rc=$?
assert_true "unreviewed-base exits 0 with no unreviewed work" "$rc"
assert_eq "unreviewed-base prints nothing with no unreviewed work" "" "$(cat "$out/unrev-none.log")"
rm -rf "$quiet"

# --- Cleanup ------------------------------------------------------------------------
rm -rf "$repo"

echo "== results: $((tests - failures))/$tests passed =="
if [ "$failures" -ne 0 ]; then
  exit 1
fi
exit 0
