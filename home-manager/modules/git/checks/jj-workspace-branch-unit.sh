#!/usr/bin/env bash
#
# Behavioral suite for the jj-workspace-branch command.
#
# jj-workspace-branch keeps a jj bookmark named after the current jj workspace pointed
# at that workspace's working-copy commit: it creates the bookmark if absent and
# re-points it at the working copy if it points elsewhere, but never moves a
# bookmark parked on a private change (a "private:" description). The command
# refuses to run in the default (primary) workspace.
#
# The suite builds throwaway jj repositories with a second workspace, runs the
# command under test, and asserts the resulting bookmarks, messages, and exit
# codes.
#
# Usage:
#   JJ_WORKSPACE_BRANCH_BIN=/path/to/jj-workspace-branch ./jj-workspace-branch-unit.sh
#
# JJ_WORKSPACE_BRANCH_BIN must point at the command under test (the built binary
# or a dev copy).

set -uo pipefail

if [ -z "${JJ_WORKSPACE_BRANCH_BIN:-}" ]; then
  echo "FATAL: JJ_WORKSPACE_BRANCH_BIN is not set; point it at the jj-workspace-branch binary under test" >&2
  exit 1
fi

command -v jj >/dev/null || { echo "FATAL: jj not on PATH" >&2; exit 1; }

BRANCH="$JJ_WORKSPACE_BRANCH_BIN"

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

# assert_false <label> <exit-code>  (expects a non-zero exit)
assert_false() {
  tests=$((tests + 1))
  if [ "$2" != "0" ]; then pass "$1"; else fail "$1" "command unexpectedly exited 0"; fi
}

# bookmark_target <repo> <name> -> commit id the local bookmark points at (empty if absent)
bookmark_target() {
  (cd "$1" && jj --ignore-working-copy log --no-graph \
    -r "bookmarks(exact:\"$2\")" -T 'commit_id')
}

# new_repo -> prints a fresh repo dir with one content commit and a ws-a workspace
new_repo() {
  local repo
  repo=$(mktemp -d) || return 1
  (
    cd "$repo" || exit 1
    jj git init >/dev/null || exit 1
    # Commits need an identity: the check sandbox has no user jj config.
    jj config set --repo user.name "Test User" >/dev/null || exit 1
    jj config set --repo user.email "test@example.com" >/dev/null || exit 1
    # The sandbox HOME has no user config, so mirror the `private()` revset alias
    # the command under test relies on.
    jj config set --repo 'revset-aliases."private()"' "description(glob:'private:*')" >/dev/null || exit 1
    printf 'content\n' > file.txt
    jj commit -m init >/dev/null || exit 1
    jj workspace add --name ws-a "$repo/ws-a" >/dev/null || exit 1
  ) >&2 || return 1
  printf '%s\n' "$repo"
}

echo "== jj-workspace-branch suite =="

repo=$(new_repo) || { echo "FATAL: repo setup failed" >&2; exit 1; }

# --- Case: creates a bookmark named after the workspace at its working copy ----------
ws_at=$( (cd "$repo/ws-a" && jj --ignore-working-copy log --no-graph -r @ -T 'commit_id') )
( cd "$repo/ws-a" && "$BRANCH" >"$out/out.log" 2>&1 ); rc=$?
assert_true "create run exits 0" "$rc"
assert_eq "bookmark named after the workspace points at the workspace's @" \
  "$ws_at" "$(bookmark_target "$repo" ws-a)"
grep -q "Bookmark 'ws-a' created at @" "$out/out.log" \
  && pass "create run reports the created bookmark" \
  || fail "create run reports the created bookmark" "$(cat "$out/out.log")"

# --- Case: a re-run while the bookmark already points at @ is a no-op ----------------------
( cd "$repo/ws-a" && "$BRANCH" >"$out/out2.log" 2>&1 ); rc=$?
assert_true "re-run at @ exits 0" "$rc"
assert_eq "re-run at @ leaves the bookmark target unchanged" \
  "$ws_at" "$(bookmark_target "$repo" ws-a)"
grep -q "Bookmark 'ws-a' already at @" "$out/out2.log" \
  && pass "re-run at @ reports the existing bookmark" \
  || fail "re-run at @ reports the existing bookmark" "$(cat "$out/out2.log")"

# --- Case: a newer commit re-points the bookmark at the new @ -------------------------------
# Committing rewrites the change the bookmark rides on (the bookmark follows the
# change), while the workspace's working copy becomes a newer change. The re-run
# must move the bookmark to the new @.
(
  cd "$repo/ws-a" || exit 1
  printf 'more\n' >> file.txt
  jj commit -m second >/dev/null || exit 1
) >&2
bm_after_commit=$(bookmark_target "$repo" ws-a)
ws_at_now=$( (cd "$repo/ws-a" && jj --ignore-working-copy log --no-graph -r @ -T 'commit_id') )
if [ -n "$bm_after_commit" ] && [ "$bm_after_commit" != "$ws_at_now" ]; then
  tests=$((tests + 1))
  pass "precondition: bookmark target differs from the workspace's new @"
else
  tests=$((tests + 1))
  fail "precondition: bookmark target differs from the workspace's new @" \
    "bookmark: [$bm_after_commit] / @: [$ws_at_now]"
fi
( cd "$repo/ws-a" && "$BRANCH" >"$out/out3.log" 2>&1 ); rc=$?
assert_true "re-run after a new commit exits 0" "$rc"
assert_eq "new commit re-points the bookmark at the new @" \
  "$ws_at_now" "$(bookmark_target "$repo" ws-a)"
grep -q "Bookmark 'ws-a' moved to @" "$out/out3.log" \
  && pass "move run reports the re-pointed bookmark" \
  || fail "move run reports the re-pointed bookmark" "$(cat "$out/out3.log")"

# --- Case: a bookmark ahead of @ is moved backwards ---------------------------------------
# The bookmark is parked on a descendant of the working copy (as after a `jj
# tug`-style relocation): the run must pull it back down to @.
(
  cd "$repo/ws-a" || exit 1
  at_commit=$(jj --ignore-working-copy log --no-graph -r @ -T 'commit_id') || exit 1
  jj new -m ahead >/dev/null 2>&1 || exit 1
  jj bookmark set ws-a -r @ >/dev/null 2>&1 || exit 1
  jj edit "$at_commit" >/dev/null 2>&1 || exit 1
) >&2
ws_at_back=$( (cd "$repo/ws-a" && jj --ignore-working-copy log --no-graph -r @ -T 'commit_id') )
( cd "$repo/ws-a" && "$BRANCH" >"$out/out4.log" 2>&1 ); rc=$?
assert_true "backwards run exits 0" "$rc"
assert_eq "bookmark is moved back down to @" \
  "$ws_at_back" "$(bookmark_target "$repo" ws-a)"

# --- Case: a bookmark parked on a private change is never moved ----------------------------
# The bookmark's target carries a "private:" description and the working copy
# has advanced past it: the run must leave the bookmark where it is.
(
  cd "$repo/ws-a" || exit 1
  jj describe -m "private: parked work" >/dev/null 2>&1 || exit 1
  jj new -m next >/dev/null 2>&1 || exit 1
) >&2
private_commit=$(bookmark_target "$repo" ws-a)
( cd "$repo/ws-a" && "$BRANCH" >"$out/out5.log" 2>&1 ); rc=$?
assert_true "private-parked run exits 0" "$rc"
assert_eq "private-parked bookmark stays on its target" \
  "$private_commit" "$(bookmark_target "$repo" ws-a)"
grep -q "parked on a private change" "$out/out5.log" \
  && pass "private-parked run reports the exemption" \
  || fail "private-parked run reports the exemption" "$(cat "$out/out5.log")"

# --- Case: the default workspace is rejected ---------------------------------------------
( cd "$repo" && "$BRANCH" >"$out/out6.log" 2>&1 ); rc=$?
assert_false "default workspace run exits non-zero" "$rc"
assert_eq "default workspace run creates no bookmark" \
  "" "$(bookmark_target "$repo" default)"
grep -q "default workspace" "$out/out6.log" \
  && pass "default workspace run reports the refusal" \
  || fail "default workspace run reports the refusal" "$(cat "$out/out6.log")"

# --- Case: extra arguments are rejected ----------------------------------------------------
before_usage=$(bookmark_target "$repo" ws-a)
( cd "$repo/ws-a" && "$BRANCH" surprise >"$out/out7.log" 2>&1 ); rc=$?
assert_false "extra argument exits non-zero" "$rc"
assert_eq "usage error leaves the bookmark untouched" \
  "$before_usage" "$(bookmark_target "$repo" ws-a)"

# --- Cleanup ------------------------------------------------------------------------------
rm -rf "$repo"

echo "== results: $((tests - failures))/$tests passed =="
if [ "$failures" -ne 0 ]; then
  exit 1
fi
exit 0
