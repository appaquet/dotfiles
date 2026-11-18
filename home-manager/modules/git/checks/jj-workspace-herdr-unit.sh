# Behavioral suite for the Herdr side of the jj workspace utilities: jj-workspace-herdr (the
# `jjwh` open command) and jj-workspace-delete (the `jjwd` delete command).
#
# Both commands drive herdr-core through `hc` only, which may run on another machine than the
# Herdr window. The suite runs the real commands against a temporary jj repository with a
# recording `hc` stub on PATH. Each recorded line keeps its arguments separate
# (`hc|run|--bg|…`), so a split or misquoted argument cannot pass as the right call.
#
# It covers the regressions that bite: the command contract, reloading an already-open
# workspace instead of starting a second terminal, the delete ordering, workspace names with
# spaces, and hosts without herdr-core. It is deliberately not exhaustive.

command -v jq >/dev/null || { echo "FATAL: jq not on PATH" >&2; exit 1; }

record="$out/record"
: >"$record"

# assert_path <label> present|absent <path>
assert_path() {
  tests=$((tests + 1))
  if { [ "$2" = present ] && [ -d "$3" ]; } || { [ "$2" = absent ] && [ ! -e "$3" ]; }; then
    pass "$1"
  else
    fail "$1" "$2 expected: $3"
  fi
}

# assert_recorded <label> <extended regex matched against whole recorded lines>
assert_recorded() {
  tests=$((tests + 1))
  if grep -Eq -- "$2" "$record"; then
    pass "$1"
  else
    fail "$1" "no recorded line matches: [$2]"$'\n'"       recorded:"$'\n'"$(sed 's/^/         /' "$record")"
  fi
}

# assert_not_recorded <label> <substring that must not appear on any recorded line>
assert_not_recorded() {
  tests=$((tests + 1))
  if grep -Fq -- "$2" "$record"; then
    fail "$1" "unexpectedly recorded a line containing [$2]:"$'\n'"$(sed 's/^/         /' "$record")"
  else
    pass "$1"
  fi
}

# assert_contains <label> <file> <text>
assert_contains() {
  tests=$((tests + 1))
  if grep -Fq -- "$3" "$2"; then
    pass "$1"
  else
    fail "$1" "[$3] not found in:"$'\n'"$(sed 's/^/         /' "$2")"
  fi
}

# new_repo -> prints a fresh repo dir holding a default workspace
new_repo() {
  local repo
  repo=$(init_repo) || return 1
  (
    cd "$repo" || exit 1
    printf 'content\n' >file.txt
    jj commit -m init >/dev/null || exit 1
  ) >&2 || return 1
  printf '%s\n' "$repo"
}

# --- herdr-core stub -----------------------------------------------------------------
# Every call is appended to $STUB_RECORD as `hc|arg|arg|…`. STUB_* variables answer for the
# core. `kill` also flags whether the workspace folder still existed when it ran, which is
# what pins the delete ordering.
stubs="$out/stubs"
mkdir -p "$stubs"
printf '#!%s\n' "$(command -v bash)" >"$stubs/hc"
cat >>"$stubs/hc" <<'HC'
printf 'hc' >>"$STUB_RECORD"
for arg in "$@"; do printf '|%s' "$arg" >>"$STUB_RECORD"; done
printf '\n' >>"$STUB_RECORD"
if [ -n "${STUB_HC_EXIT:-}" ]; then exit "$STUB_HC_EXIT"; fi
answer=""
case "${1:-}" in
  ls)
    case "$*" in
      *"--label herdr.space="*) answer="${STUB_HC_BY_SPACE:-}" ;;
      *) answer="${STUB_HC_ALL:-}" ;;
    esac
    if [ -z "$answer" ]; then answer='{"terminals":[]}'; fi
    printf '%s\n' "$answer"
    ;;
  kill)
    if [ -d "${STUB_KILL_WATCH:-/nonexistent}" ]; then
      printf 'hc.kill-ran-with-workspace-present\n' >>"$STUB_RECORD"
    fi
    ;;
esac
exit 0
HC
chmod +x "$stubs/hc"

# reset_stubs - empty the recording and clear the answers a case configures.
reset_stubs() {
  : >"$record"
  export STUB_RECORD="$record"
  unset STUB_HC_ALL STUB_HC_BY_SPACE STUB_HC_EXIT STUB_KILL_WATCH
}

saved_path="$PATH"
export PATH="$stubs:$PATH"

echo "== jj-workspace-herdr suite =="

repo=$(new_repo) || { echo "FATAL: repo setup failed" >&2; exit 1; }
root=$(realpath "$repo")

# --- a new name creates the workspace and its space --------------------------------
reset_stubs
( cd "$repo" && jj-workspace-herdr brand-new ) >"$out/new.out" 2>"$out/new.err"; rc=$?
assert_true "open: a new workspace succeeds" "$rc"
assert_path "open: creates the jj workspace under .workspaces" present "$root/.workspaces/brand-new"
assert_recorded "open: starts a terminal in the folder, labelled with its space and nothing else" \
  "^hc\|run\|--bg\|--keep\|--no-parent\|--cwd\|[^|]*/\.workspaces/brand-new\|--label\|herdr\.space=sp[0-9a-f]{32}\$"
assert_not_recorded "open: never drives the Herdr window" "herdr-app"

# --- an already-open workspace starts no second terminal ---------------------------
( cd "$repo" && jj-workspace-add focus-me ) >/dev/null 2>&1 \
  || { echo "FATAL: focus fixture setup failed" >&2; exit 1; }
reset_stubs
export STUB_HC_BY_SPACE='{"terminals":[{"address":"t9"}]}'
( cd "$repo" && jj-workspace-herdr focus-me ) >/dev/null 2>"$out/labelled.err"; rc=$?
assert_true "open: an already opened workspace succeeds" "$rc"
assert_recorded "open: asks for the space's terminals by its derived id" \
  "^hc\|ls\|--json\|--label\|herdr\.space=sp[0-9a-f]{32}\$"
assert_not_recorded "open: starts no second terminal for the same workspace" "hc|run"
assert_contains "open: says the workspace is already open" "$out/labelled.err" "is already open"

# --- a terminal still at the workspace root counts as open -------------------------
reset_stubs
export STUB_HC_ALL="{\"terminals\":[{\"address\":\"t7\",\"cwd\":\"$root/.workspaces/focus-me/sub\"},{\"address\":\"t6\",\"cwd\":\"/elsewhere\"}]}"
( cd "$repo" && jj-workspace-herdr focus-me ) >/dev/null 2>"$out/cwd.err"; rc=$?
assert_true "open: a space left in the folder by someone else succeeds" "$rc"
assert_not_recorded "open: starts no terminal when the folder already has one" "hc|run"
assert_contains "open: reports that workspace as already open" "$out/cwd.err" "is already open"

# --- workspace names with spaces stay one argument ---------------------------------
reset_stubs
( cd "$repo" && jj-workspace-herdr "ws spaced" ) >/dev/null 2>&1; rc=$?
assert_true "open: a workspace name with a space succeeds" "$rc"
assert_recorded "open: passes the folder with its space as one argument" \
  "^hc\|run\|.*\|--cwd\|[^|]*/\.workspaces/ws spaced\|--label\|herdr\.space=sp[0-9a-f]{32}\$"

# --- an unreachable herdr-core refuses instead of starting a duplicate -------------
reset_stubs
export STUB_HC_EXIT=1
( cd "$repo" && jj-workspace-herdr offline ) >/dev/null 2>"$out/offline.err"; rc=$?
assert_false "open: an unreachable herdr-core fails" "$rc"
assert_contains "open: explains that herdr-core could not be asked" "$out/offline.err" "cannot ask herdr-core"
assert_not_recorded "open: starts no terminal when the lookup failed" "hc|run"

# --- delete removes the workspace, then ends the space's terminals -----------------
( cd "$repo" && jj workspace add --name doomed "$repo/doomed" ) >/dev/null 2>&1 \
  || { echo "FATAL: delete fixture setup failed" >&2; exit 1; }
reset_stubs
export STUB_HC_ALL="{\"terminals\":[{\"address\":\"t5\",\"cwd\":\"$root/doomed\"},{\"address\":\"t9\",\"cwd\":\"/elsewhere\"}]}"
export STUB_HC_BY_SPACE='{"terminals":[{"address":"t5"},{"address":"t4"}]}'
export STUB_KILL_WATCH="$root/doomed"
( cd "$repo" && jj-workspace-delete doomed ) >/dev/null 2>"$out/del.err"; rc=$?
assert_true "delete: an existing workspace succeeds" "$rc"
assert_path "delete: removes the workspace folder" absent "$root/doomed"
assert_recorded "delete: ends every terminal the space held" "^hc\|kill\|t4$"
assert_recorded "delete: ends the first terminal too" "^hc\|kill\|t5$"
assert_not_recorded "delete: ends them only after removing the workspace" "hc.kill-ran-with-workspace-present"
assert_eq "delete: the kills are the last thing done" "hc|kill|t5" "$(tail -n 1 "$record")"

# --- a workspace without a space deletes without killing anything ------------------
( cd "$repo" && jj workspace add --name spartan "$repo/spartan" ) >/dev/null 2>&1 \
  || { echo "FATAL: spartan fixture setup failed" >&2; exit 1; }
reset_stubs
( cd "$repo" && jj-workspace-delete spartan ) >/dev/null 2>&1; rc=$?
assert_true "delete: a workspace with no space succeeds" "$rc"
assert_path "delete: removes the workspace folder" absent "$root/spartan"
assert_not_recorded "delete: ends no terminal when no space exists" "hc|kill"

# --- hosts without herdr-core stay usable -----------------------------------------
# Only meaningful where no herdr-core is installed (the check sandbox); nothing in PATH can
# hide an installed binary from `command -v`.
ambient_hc=$(PATH="$saved_path" command -v hc 2>/dev/null || true)
if [ -n "$ambient_hc" ]; then
  echo "skip - herdr-core is installed at $ambient_hc; the no-core case needs a host without it"
else
  reset_stubs
  ( export PATH="$saved_path"
    cd "$repo" && jj-workspace-herdr ghost
  ) >/dev/null 2>"$out/nohc.err"; rc=$?
  assert_false "open: refuses without herdr-core" "$rc"
  assert_path "open: creates no workspace without herdr-core" absent "$root/.workspaces/ghost"
  assert_contains "open: names herdr-core as the missing piece" "$out/nohc.err" "herdr-core (hc)"

  ( cd "$repo" && jj workspace add --name lonely "$repo/lonely" ) >/dev/null 2>&1
  ( export PATH="$saved_path"
    cd "$repo" && jj-workspace-delete lonely
  ) >/dev/null 2>&1; rc=$?
  assert_true "delete: still deletes without herdr-core" "$rc"
  assert_path "delete: removes the workspace folder without herdr-core" absent "$root/lonely"
fi

# --- argument guards ---------------------------------------------------------------
reset_stubs
( cd "$repo" && jj-workspace-herdr one two ) >/dev/null 2>&1; rc=$?
assert_false "open: two arguments are rejected" "$rc"
( cd "$repo" && jj-workspace-herdr "" ) >/dev/null 2>&1; rc=$?
assert_false "open: an empty name is rejected" "$rc"
( cd "$repo" && jj-workspace-delete default ) >/dev/null 2>&1; rc=$?
assert_false "delete: the default workspace is refused" "$rc"
assert_eq "guards: rejected arguments reach no Herdr CLI" "" "$(cat "$record")"

PATH="$saved_path"

finish
