# Shared helpers for the jj-utils checks. checks/default.nix puts this file in front of every
# suite, so a suite holds only its own fixtures and cases. The packaged commands are on PATH,
# and JJ_CONFIG carries the test identity plus the real aliases from jujutsu.nix.

set -uo pipefail

command -v jj >/dev/null || { echo "FATAL: jj not on PATH" >&2; exit 1; }

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

# init_repo -> prints the path of a fresh, empty jj repository under $out
init_repo() {
  local repo
  repo=$(mktemp -d "$out/repo.XXXXXX") || return 1
  jj git init "$repo" >/dev/null 2>&1 || return 1
  printf '%s\n' "$repo"
}

# rev_of <revset> <template> [jj options...] -> template output for the matching revisions,
# read without snapshotting. Pass `-R <repo>` to read another repository.
rev_of() {
  jj --ignore-working-copy log --no-graph -r "$1" -T "$2" "${@:3}"
}

# op_id [jj options...] -> id of the most recent operation
op_id() {
  jj --ignore-working-copy op log --no-graph --limit 1 -T 'id' "$@"
}

# finish -> print the totals and exit non-zero when any assertion failed
finish() {
  echo "== results: $((tests - failures))/$tests passed =="
  exit "$((failures != 0))"
}
