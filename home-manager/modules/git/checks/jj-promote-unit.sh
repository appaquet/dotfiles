#!/usr/bin/env bash
#
# Behavioral suite for the jj-promote command (see the phase doc "jj promote agent commits").
#
# jj-promote promotes agent-authored jujutsu changes by stripping the
# `private: agent: ` (or legacy `private: claude: `) description prefix, which moves the
# change outside the private() revset and makes it pushable while keeping its
# conventional-commit message untouched.
#
# The suite builds throwaway jj repositories, runs the command under test, and asserts
# resulting descriptions byte-exactly plus repository-level effects (dry-run leaves no
# operation, re-runs are no-ops, unknown revsets fail loudly).
#
# Usage:
#   JJ_PROMOTE_BIN=/path/to/jj-promote ./jj-promote-unit.sh
#
# JJ_PROMOTE_BIN must point at the command under test (the built binary or a dev copy).

set -uo pipefail

if [ -z "${JJ_PROMOTE_BIN:-}" ]; then
  echo "FATAL: JJ_PROMOTE_BIN is not set; point it at the jj-promote binary under test" >&2
  exit 1
fi

command -v jj >/dev/null || { echo "FATAL: jj not on PATH" >&2; exit 1; }


PROMOTE="$JJ_PROMOTE_BIN"
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

# desc_of <repo> <change-id>  -> raw description bytes
desc_of() {
  (cd "$1" && jj log --no-graph -r "$2" -T 'description')
}

# private_of <repo> <change-id>  -> "true"/"false" whether the change is still in private()
private_of() {
  local out
  out=$( (cd "$1" && jj log --no-graph \
    -r "description(glob:'private:*') & $2" -T 'description.first_line()') )
  if [ -n "$out" ]; then echo "private"; else echo "public"; fi
}

# first_op_id <repo> -> id of the most recent operation
first_op_id() {
  (cd "$1" && jj op log --no-graph --limit 1 \
    -T 'id.short(12) ++ "\n"')
}

# new_repo -> prints a fresh repo dir seeded with a master bookmark holding one commit
new_repo() {
  local repo
  repo=$(mktemp -d) || return 1
  (
    cd "$repo" || exit 1
    jj git init >/dev/null || exit 1
    # Commits need an identity before any push: the check sandbox has no user jj config.
    jj config set --repo user.name "Test User" >/dev/null || exit 1
    jj config set --repo user.email "test@example.com" >/dev/null || exit 1
    jj describe -m "init" >/dev/null || exit 1
    jj bookmark set master -r @ >/dev/null || exit 1
    jj new >/dev/null || exit 1
  ) >&2 || return 1
  printf '%s\n' "$repo"
}

# add_change <repo> <description-args...>  finalize the current @ as a content commit and
# leave a fresh empty @ on top
add_change() {
  local repo=$1
  shift
  (
    cd "$repo" || exit 1
    printf '%s\n' "content-$RANDOM" > file.txt
    jj commit "$@" >/dev/null || exit 1
  ) >&2
}

change_id_of() {
  (cd "$1" && jj log --no-graph -r "$2" -T 'change_id')
}

echo "== jj-promote suite =="

# --- Case: single-line agent change, explicit revset ----------------------------
repo=$(new_repo) || { echo "FATAL: repo setup failed" >&2; exit 1; }
add_change "$repo" -m 'private: agent: feat(home): add example command'
cid_single=$(change_id_of "$repo" '@-')
(cd "$repo" && "$PROMOTE" "$cid_single" >"$out/out.log" 2>&1); rc=$?
assert_true "single-line promote exits 0" "$rc"
assert_eq "single-line description stripped to conventional form" \
  'feat(home): add example command' \
  "$(desc_of "$repo" "$cid_single")"
assert_eq "single-line change left private()" \
  "public" "$(private_of "$repo" "$cid_single")"

# --- Case: multiline agent change keeps its body byte-exact ---------------------
add_change "$repo" -m 'private: agent: fix(nix): guard workspace delete' -m 'body line one
body line two'
cid_multi=$(change_id_of "$repo" '@-')
(cd "$repo" && "$PROMOTE" "$cid_multi" >"$out/out.log" 2>&1); rc=$?
assert_true "multiline promote exits 0" "$rc"
assert_eq "multiline description keeps body byte-exact minus prefix" \
  'fix(nix): guard workspace delete

body line one
body line two' \
  "$(desc_of "$repo" "$cid_multi")"

# --- Case: legacy claude prefix is also promoted --------------------------------
add_change "$repo" -m 'private: claude: docs(readme): refresh cheat sheet'
cid_claude=$(change_id_of "$repo" '@-')
(cd "$repo" && "$PROMOTE" "$cid_claude" >"$out/out.log" 2>&1); rc=$?
assert_true "legacy claude promote exits 0" "$rc"
assert_eq "legacy claude prefix stripped" \
  'docs(readme): refresh cheat sheet' \
  "$(desc_of "$repo" "$cid_claude")"

# --- Case: protected and unrelated descriptions are skipped ---------------------
add_change "$repo" -m 'private: proj - some-project'
cid_proj=$(change_id_of "$repo" '@-')
add_change "$repo" -m 'private: scratch note'
cid_scratch=$(change_id_of "$repo" '@-')
add_change "$repo" -m 'feat(already): public change'
cid_public=$(change_id_of "$repo" '@-')
add_change "$repo" -m 'private: agent: '
cid_prefixonly=$(change_id_of "$repo" '@-')

revset="$cid_proj | $cid_scratch | $cid_public | $cid_prefixonly"
before_proj=$(desc_of "$repo" "$cid_proj")
before_scratch=$(desc_of "$repo" "$cid_scratch")
before_public=$(desc_of "$repo" "$cid_public")
before_prefixonly=$(desc_of "$repo" "$cid_prefixonly")
(cd "$repo" && "$PROMOTE" "$revset" >"$out/out.log" 2>&1)
rc=$?
assert_true "skip-only run exits 0" "$rc"
assert_eq "proj commit description untouched" "$before_proj" "$(desc_of "$repo" "$cid_proj")"
assert_eq "scratch private description untouched" "$before_scratch" "$(desc_of "$repo" "$cid_scratch")"
assert_eq "already-public description untouched" "$before_public" "$(desc_of "$repo" "$cid_public")"
assert_eq "prefix-only description untouched" "$before_prefixonly" "$(desc_of "$repo" "$cid_prefixonly")"
assert_eq "prefix-only change stays private" "private" "$(private_of "$repo" "$cid_prefixonly")"

# --- Case: default revset promotes agent changes above trunk --------------------
# the earlier agent changes are already promoted; add a fresh agent chain instead
add_change "$repo" -m 'private: agent: chore(ci): tune check job'
add_change "$repo" -m 'private: agent: perf(shell): speed up prompt'
cid_agent_a=$(change_id_of "$repo" '@--')
cid_agent_b=$(change_id_of "$repo" '@-')
(cd "$repo" && "$PROMOTE" >"$out/out.log" 2>&1); rc=$?
assert_true "bare invoke exits 0" "$rc"
assert_eq "bare invoke promotes agent change A via default revset" \
  'chore(ci): tune check job' \
  "$(desc_of "$repo" "$cid_agent_a")"
assert_eq "bare invoke promotes agent change B via default revset" \
  'perf(shell): speed up prompt' \
  "$(desc_of "$repo" "$cid_agent_b")"
assert_eq "proj commit still skipped after bare invoke" "$before_proj" "$(desc_of "$repo" "$cid_proj")"
assert_eq "scratch private still skipped after bare invoke" "$before_scratch" "$(desc_of "$repo" "$cid_scratch")"

# --- Case: bare invoke leaves commits at or below trunk untouched -----------------
# trunk() is the master@origin remote bookmark, so a published commit sits outside
# trunk()..@ and must never be swept by a bare invoke. This pins the blast radius of
# the default revset: the remote is only created here, after the earlier cases ran.
add_change "$repo" -m 'private: agent: fix(trunk): buried on mainline'
cid_buried=$(change_id_of "$repo" '@-')
git init --bare "$out/upstream.git" >/dev/null 2>&1
(cd "$repo" && jj git remote add upstream "$out/upstream.git" >/dev/null 2>&1); rc=$?
assert_true "adding a remote to the test repo succeeds" "$rc"
(cd "$repo" && jj bookmark set master -r "$cid_buried" >/dev/null 2>&1); rc=$?
assert_true "moving the trunk bookmark onto the agent commit succeeds" "$rc"
(cd "$repo" && jj git push --allow-private -b master >/dev/null 2>&1); rc=$?
assert_true "publishing the trunk bookmark succeeds" "$rc"
(cd "$repo" && "$PROMOTE" >"$out/out.log" 2>&1); rc=$?
assert_true "bare invoke with trunk at an agent commit exits 0" "$rc"
assert_eq "agent commit at trunk stays out of the default trunk()..@ range" \
  'private: agent: fix(trunk): buried on mainline' \
  "$(desc_of "$repo" "$cid_buried")"

# --- Case: re-run after promotion is a no-op ------------------------------------
op_before=$(first_op_id "$repo")
(cd "$repo" && "$PROMOTE" >"$out/out2.log" 2>&1); rc=$?
assert_true "re-run exits 0" "$rc"
op_after=$(first_op_id "$repo")
assert_eq "re-run creates no mutation" "$op_before" "$op_after"

# --- Case: --dry-run reports without mutating -----------------------------------
add_change "$repo" -m 'private: agent: refactor(vcs): extract helper'
cid_dry=$(change_id_of "$repo" '@-')
op_before=$(first_op_id "$repo")
(cd "$repo" && "$PROMOTE" --dry-run "$cid_dry" >"$out/out3.log" 2>&1); rc=$?
assert_true "dry-run exits 0" "$rc"
assert_eq "dry-run leaves description untouched" \
  'private: agent: refactor(vcs): extract helper' \
  "$(desc_of "$repo" "$cid_dry")"
op_after=$(first_op_id "$repo")
assert_eq "dry-run creates no mutation" "$op_before" "$op_after"

# --- Case: unknown revset fails loudly ------------------------------------------
(cd "$repo" && "$PROMOTE" 'this is not a revset((' >/dev/null 2>&1); rc=$?
assert_false "invalid revset exits non-zero" "$rc"

# --- Cleanup ---------------------------------------------------------------------
rm -rf "$repo"

echo "== results: $((tests - failures))/$tests passed =="
if [ "$failures" -ne 0 ]; then
  exit 1
fi
exit 0
