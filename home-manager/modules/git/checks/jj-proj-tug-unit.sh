#!/usr/bin/env bash
# Exercise the packaged tug command against throwaway JJ repositories.
set -euo pipefail

: "${JJ_PROJ_TUG_BIN:?Point JJ_PROJ_TUG_BIN at the packaged jj-proj-tug}"
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
export HOME="$out/home" JJ_CONFIG="$out/jj-config"
mkdir -p "$HOME" "$JJ_CONFIG"

assert_eq() {
  if [ "$2" != "$3" ]; then
    printf 'FAIL - %s\nexpected: [%s]\n  actual: [%s]\n' "$1" "$2" "$3" >&2
    exit 1
  fi
}

change_id() {
  jj --ignore-working-copy log --no-graph -r "$1" -T 'change_id'
}

commit_id() {
  jj --ignore-working-copy log --no-graph -r "$1" -T 'commit_id'
}

operation() {
  jj --ignore-working-copy op log --no-graph --limit 1 -T 'id'
}

bookmark_changes() {
  jj --ignore-working-copy bookmark list -T 'name ++ ":" ++ normal_target.change_id() ++ "\n"'
}

new_repo() {
  cd "$(mktemp -d "$out/repo.XXXXXX")"
  jj git init
  jj config set --repo user.name 'Test User'
  jj config set --repo user.email 'test@example.com'
  jj config set --repo 'revset-aliases."proj()"' "description(glob:'private: proj*')"
  jj config set --repo 'revset-aliases."private()"' "description(glob:'private:*')"
  jj config set --repo aliases.tug '["bookmark","move","--from","heads(::@- & bookmarks())","--to","heads(::@- & ~private())","--allow-backwards"]'

  printf 'base\n' > base.txt
  jj commit -m base
  jj bookmark create base -r @-
}

add_project() {
  ln -s test-project-docs proj
  jj commit -m 'private: proj - test'
  project=$(change_id @-)
}

build_stack() {
  add_project
  printf 'first change\n' > first.txt
  jj commit -m first
  jj bookmark create work -r @-
  printf 'second change\n' > second.txt
  jj commit -m second
  tip=$(change_id @-)
}

check_project_only() {
  local dirty="$1" working bookmarks placed
  new_repo
  build_stack
  working=$(change_id @)
  if [ "$dirty" = false ]; then
    jj bookmark create "$(commit_id "$project")" -r base
    jj bookmark create "$(commit_id @)" -r "$tip"
  fi
  bookmarks=$(bookmark_changes)

  if [ "$dirty" = true ]; then
    printf 'unsnapshotted work\n' > wip.txt
  fi
  "$JJ_PROJ_TUG_BIN" --project-only

  assert_eq 'the working copy ends empty' '' "$(jj diff --summary -r @)"
  assert_eq 'the original project is the sole parent' "$project" "$(change_id @-)"
  assert_eq 'the project link survives the move' test-project-docs "$(readlink proj)"
  assert_eq 'the work below the project no longer contains the link' \
    $'base.txt\nfirst.txt\nsecond.txt' "$(jj file list -r "$tip")"
  assert_eq 'bookmarks stay on their original logical changes' "$bookmarks" "$(bookmark_changes)"

  if [ "$dirty" = true ]; then
    assert_eq 'the project follows the original dirty working change' "$working" "$(change_id @--)"
    assert_eq 'work remains in the original change' 'A wip.txt' "$(jj diff --summary -r "$working")"
    assert_eq 'working content is preserved' 'unsnapshotted work' "$(jj file show -r "$working" wip.txt)"
  else
    assert_eq 'the empty working-copy change is reused' "$working" "$(change_id @)"
    assert_eq 'the project follows the original work tip' "$tip" "$(change_id @--)"
  fi

  placed=$(operation)
  "$JJ_PROJ_TUG_BIN" --project-only
  assert_eq 'the second call adds no operation' "$placed" "$(operation)"
  printf 'ok - project-only with dirty=%s\n' "$dirty"
}

check_project_parent_with_dirty_work() {
  local work bookmarks
  new_repo
  add_project
  work=$(change_id @)
  bookmarks=$(bookmark_changes)
  printf 'current edits\n' > wip.txt
  "$JJ_PROJ_TUG_BIN" --project-only

  assert_eq 'a project already under dirty work still gets moved' "$work" "$(change_id @--)"
  assert_eq 'the project comes after the original work' "$project" "$(change_id @-)"
  assert_eq 'a fresh working copy ends empty' '' "$(jj diff --summary -r @)"
  assert_eq 'original work retains its edits' 'current edits' "$(jj file show -r "$work" wip.txt)"
  assert_eq 'the branch behind the work does not advance' "$bookmarks" "$(bookmark_changes)"
  printf 'ok - project starts as the parent of dirty @\n'
}

check_refusal() {
  local explanation="$1" before
  before=$(operation)
  if "$JJ_PROJ_TUG_BIN" --project-only >"$out/refusal.log" 2>&1; then
    printf 'FAIL - expected refusal: %s\n' "$explanation" >&2
    exit 1
  fi
  if ! grep -F "$explanation" "$out/refusal.log"; then
    printf 'FAIL - expected diagnostic: %s\n' "$explanation" >&2
    cat "$out/refusal.log" >&2
    exit 1
  fi
  assert_eq 'refusal leaves repository state unchanged' "$before" "$(operation)"
}

check_project_parent_with_dirty_work
check_project_only false
check_project_only true

new_repo
check_refusal 'No private project change'

new_repo
build_stack
jj workspace add --name side -r @- "$out/side-workspace"
check_refusal 'side descendants'

new_repo
build_stack
jj workspace add --name shared -r @- "$out/shared-workspace"
jj -R "$out/shared-workspace" edit "$(change_id @)"
printf 'dirty shared working copy\n' > wip.txt
check_refusal 'another workspace'

new_repo
build_stack
jj new base
printf 'other line\n' > other.txt
jj commit -m other
jj new "$tip" @-
check_refusal 'merge'

new_repo
build_stack
old_working=$(change_id @)
printf 'legacy dirty work\n' > wip.txt
"$JJ_PROJ_TUG_BIN"
assert_eq 'legacy installs a fresh empty working copy' '' "$(jj diff --summary -r @)"
assert_eq 'legacy moves the branch to the previous working-copy change' "$old_working" "$(change_id work)"
assert_eq 'legacy puts the project on top of the branch' "$old_working" "$(change_id @--)"
assert_eq 'legacy project is directly below the fresh working copy' "$project" "$(change_id @-)"
printf 'ok - legacy combined tug\n'
