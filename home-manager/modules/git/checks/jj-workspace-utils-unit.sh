#!/usr/bin/env bash
#
# Behavioral suite for the jj workspace utilities: jj-workspace-name, -exists, -select,
# -path, and -add.
#
# Every one of these commands hands a workspace name to another command, and jj renders
# names that need quoting (e.g. names with spaces) with quotes in its listing. The suite
# therefore holds a plain name and a quoted name in the same repo and asserts that each
# command reports, selects, and resolves both.
#
# Usage:
#   JJ_UTILS_BIN=/path/to/bin ./jj-workspace-utils-unit.sh
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

# assert_false <label> <exit-code>  (expects a non-zero exit)
assert_false() {
  tests=$((tests + 1))
  if [ "$2" != "0" ]; then pass "$1"; else fail "$1" "command unexpectedly exited 0"; fi
}

# new_repo -> prints a fresh repo dir holding a default, a plain, and a quoted workspace
new_repo() {
  local repo
  repo=$(mktemp -d) || return 1
  (
    cd "$repo" || exit 1
    jj git init >/dev/null || exit 1
    # Commits need an identity: the check sandbox has no user jj config.
    jj config set --repo user.name "Test User" >/dev/null || exit 1
    jj config set --repo user.email "test@example.com" >/dev/null || exit 1
    printf 'content\n' > file.txt
    jj commit -m init >/dev/null || exit 1
    jj workspace add --name ws-a "$repo/ws-a" >/dev/null || exit 1
    jj workspace add --name "ws spaced" "$repo/ws spaced" >/dev/null || exit 1
  ) >&2 || return 1
  printf '%s\n' "$repo"
}

echo "== jj-workspace-utils suite =="

repo=$(new_repo) || { echo "FATAL: repo setup failed" >&2; exit 1; }

# --- Case: the serving workspace is named without jj's quoting ----------------------
( cd "$repo" && jj-workspace-name ) >"$out/name1.log" 2>&1; rc=$?
assert_true "name in the default workspace exits 0" "$rc"
assert_eq "name in the default workspace" "default" "$(cat "$out/name1.log")"

( cd "$repo/ws-a" && jj-workspace-name ) >"$out/name2.log" 2>&1; rc=$?
assert_true "name in a plain workspace exits 0" "$rc"
assert_eq "name in a plain workspace" "ws-a" "$(cat "$out/name2.log")"

( cd "$repo/ws spaced" && jj-workspace-name ) >"$out/name3.log" 2>&1; rc=$?
assert_true "name in a workspace whose name jj quotes exits 0" "$rc"
assert_eq "name in a workspace whose name jj quotes" "ws spaced" "$(cat "$out/name3.log")"

# --- Case: existence matching is exact, quoted names included -----------------------
( cd "$repo" && jj-workspace-exists default ) >/dev/null 2>&1; rc=$?
assert_true "exists: the default workspace" "$rc"

( cd "$repo" && jj-workspace-exists ws-a ) >/dev/null 2>&1; rc=$?
assert_true "exists: a plain workspace" "$rc"

( cd "$repo" && jj-workspace-exists "ws spaced" ) >/dev/null 2>&1; rc=$?
assert_true "exists: a workspace whose name jj quotes" "$rc"

( cd "$repo" && jj-workspace-exists "ws spaced " ) >/dev/null 2>&1; rc=$?
assert_false "exists: a trailing space does not match" "$rc"

( cd "$repo" && jj-workspace-exists "ws-a-x" ) >/dev/null 2>&1; rc=$?
assert_false "exists: an unknown name is reported missing" "$rc"

# --- Case: a selected name resolves again ------------------------------------------
( cd "$repo" && jj-workspace-select "ws spaced" ) >"$out/select.log" 2>&1; rc=$?
assert_true "select: an existing name exits 0" "$rc"
assert_eq "select: prints the name without quoting" "ws spaced" "$(cat "$out/select.log")"

assert_eq "select: the printed name resolves to its path" \
  "$(realpath "$repo/ws spaced")" \
  "$( cd "$repo" && jj-workspace-path "$(cat "$out/select.log")" )"

( cd "$repo" && jj-workspace-select "ws-a-x" ) >/dev/null 2>&1; rc=$?
assert_false "select: an unknown name is rejected" "$rc"

# --- Case: interactive focus preserves candidates and explicit selection ------------
( cd "$repo" && jj workspace add --name ws-a-extra "$repo/ws-a-extra" ) >/dev/null 2>&1 \
  || { echo "FATAL: selector fixture setup failed" >&2; exit 1; }
mkdir -p "$out/bin"
printf '#!%s\n' "$(command -v bash)" >"$out/bin/fzf"
cat >>"$out/bin/fzf" <<'FZF'
printf 'called\n' >>"$FZF_TEST_DIR/calls"
printf '%s\n' "$@" >"$FZF_TEST_DIR/args"
cat >"$FZF_TEST_DIR/input"
printf '%s' "${FZF_TEST_RESULT:-}"
exit "${FZF_TEST_STATUS:-0}"
FZF
chmod +x "$out/bin/fzf"
export FZF_TEST_DIR="$out" FZF_TEST_RESULT="ws spaced"
saved_path="$PATH"
PATH="$out/bin:$PATH"
: >"$out/calls"
display_args=$(printf '%s\n' --prompt 'Workspace > ' --height '40%' --layout reverse --border)
candidates=$(printf '%s\n' default 'ws spaced' ws-a ws-a-extra)
position=0
for workspace in default 'ws spaced' ws-a ws-a-extra; do
  position=$((position + 1))
  workspace_path="$repo/$workspace"
  if [ "$workspace" = default ]; then workspace_path="$repo"; fi
  ( cd "$workspace_path" && jj-workspace-select ) >"$out/pick.log" 2>"$out/pick.err"; rc=$?
  assert_eq "select: interactive from $workspace exits 0" 0 "$rc"
  assert_eq "select: from $workspace returns the chosen name" 'ws spaced' "$(cat "$out/pick.log")"
  assert_eq "select: from $workspace preserves all candidates in order" "$candidates" "$(cat "$out/input")"
  assert_eq "select: from $workspace focuses its exact row without filtering or accepting" \
    "$display_args"$'\n--bind\n'"load:pos($position)" "$(cat "$out/args")"
done

: >"$out/calls"
for workspace in default ws-a 'ws spaced'; do
  ( cd "$repo" && jj-workspace-select "$workspace" ) >"$out/explicit.log" 2>&1; rc=$?
  assert_eq "select: explicit $workspace exits 0" 0 "$rc"
  assert_eq "select: explicit $workspace is returned unchanged" "$workspace" "$(cat "$out/explicit.log")"
done
for workspace in '' ws-a-x; do
  ( cd "$repo" && jj-workspace-select "$workspace" ) >/dev/null 2>&1; rc=$?
  assert_false "select: invalid explicit name '$workspace' fails" "$rc"
done
( cd "$repo" && jj-workspace-select ws-a ws-a-extra ) >/dev/null 2>&1; rc=$?
assert_false "select: too many arguments fail" "$rc"
assert_eq "select: explicit targets and usage failures bypass fzf" '' "$(cat "$out/calls")"

for status in 0 130; do
  ( export FZF_TEST_RESULT='' FZF_TEST_STATUS="$status"
    cd "$repo" && jj-workspace-select
  ) >"$out/cancel.log" 2>"$out/cancel.err"; rc=$?
  assert_eq "select: empty output or cancellation ($status) exits 1" 1 "$rc"
  assert_eq "select: empty output or cancellation ($status) emits no name" '' "$(cat "$out/cancel.log")"
done

# A current workspace absent from the captured list keeps ordinary focus.
printf '#!%s\n' "$(command -v bash)" >"$out/bin/jj-workspace-name"
cat >>"$out/bin/jj-workspace-name" <<'CURRENT'
printf '%s\n' 'not-in-candidates'
exit "${CURRENT_TEST_STATUS:-0}"
CURRENT
chmod +x "$out/bin/jj-workspace-name"
( cd "$repo" && jj-workspace-select ) >"$out/fallback.log" 2>"$out/fallback.err"; rc=$?
assert_eq "select: missing current row still permits selection" 0 "$rc"
assert_eq "select: missing current row returns the chosen name" 'ws spaced' "$(cat "$out/fallback.log")"
assert_eq "select: missing current row adds no positioning binding" "$display_args" "$(cat "$out/args")"
assert_eq "select: missing current row keeps every candidate" "$candidates" "$(cat "$out/input")"

: >"$out/calls"
( export CURRENT_TEST_STATUS=1
  cd "$repo" && jj-workspace-select
) >"$out/current-failed.log" 2>"$out/current-failed.err"; rc=$?
assert_false "select: failed current-name lookup fails" "$rc"
assert_eq "select: failed current-name lookup emits no name" '' "$(cat "$out/current-failed.log")"
assert_eq "select: failed current-name lookup does not open fzf" '' "$(cat "$out/calls")"
: >"$out/calls"
( cd "$out" && jj-workspace-select ) >"$out/list-failed.log" 2>"$out/list-failed.err"; rc=$?
assert_false "select: failed candidate listing fails" "$rc"
assert_eq "select: failed candidate listing emits no name" '' "$(cat "$out/list-failed.log")"
assert_eq "select: failed candidate listing does not open fzf" '' "$(cat "$out/calls")"
PATH="$saved_path"

# --- Case: workspace paths are the real directories ---------------------------------
assert_eq "path: a workspace whose name jj quotes" \
  "$(realpath "$repo/ws spaced")" "$( cd "$repo" && jj-workspace-path "ws spaced" )"

assert_eq "path: the default workspace as seen from itself" \
  "$(realpath "$repo")" "$( cd "$repo" && jj-workspace-path default )"

assert_eq "path: the default workspace as seen from a child workspace" \
  "$(realpath "$repo")" "$( cd "$repo/ws-a" && jj-workspace-path default )"

( cd "$repo" && jj-workspace-path "ws-a-x" ) >/dev/null 2>&1; rc=$?
assert_false "path: an unknown name is rejected" "$rc"

# --- Case: adding a workspace refuses duplicates and honours the layout -------------
( cd "$repo" && jj-workspace-add "ws spaced" ) >"$out/add1.log" 2>&1; rc=$?
assert_false "add: an existing name is refused" "$rc"
grep -q "already exists" "$out/add1.log" \
  && pass "add: the refusal reports the existing workspace" \
  || fail "add: the refusal reports the existing workspace" "$(cat "$out/add1.log")"

( cd "$repo" && jj-workspace-add fresh ) >"$out/add2.log" 2>&1; rc=$?
assert_true "add: a new name is created" "$rc"

( cd "$repo" && jj-workspace-exists fresh ) >/dev/null 2>&1; rc=$?
assert_true "add: the created workspace is listed afterwards" "$rc"

assert_eq "add: the created workspace lands under .workspaces" \
  "$(realpath "$repo/.workspaces/fresh")" "$( cd "$repo" && jj-workspace-path fresh )"

# --- Case: argument guards ----------------------------------------------------------
( cd "$repo" && jj-workspace-name surprise ) >/dev/null 2>&1; rc=$?
assert_false "name: extra arguments are rejected" "$rc"

( cd "$repo" && jj-workspace-exists ) >/dev/null 2>&1; rc=$?
assert_false "exists: a missing name is rejected" "$rc"

( cd "$repo" && jj-workspace-path ) >/dev/null 2>&1; rc=$?
assert_false "path: a missing name is rejected" "$rc"

# --- Cleanup ------------------------------------------------------------------------
rm -rf "$repo"

echo "== results: $((tests - failures))/$tests passed =="
if [ "$failures" -ne 0 ]; then
  exit 1
fi
exit 0
