# Exercise jj-proj-tug against throwaway JJ repositories. Fixture steps run under `set -e`, so
# a failed setup or an unexpected command failure stops the suite.
set -e

bookmark_changes() {
  jj --ignore-working-copy bookmark list -T 'name ++ ":" ++ normal_target.change_id() ++ "\n"'
}

new_repo() {
  cd "$(init_repo)"
  printf 'base\n' > base.txt
  jj commit -m base
  jj bookmark create base -r @-
}

add_project() {
  ln -s test-project-docs proj
  jj commit -m 'private: proj - test'
  project=$(rev_of @- change_id)
}

build_stack() {
  add_project
  printf 'first change\n' > first.txt
  jj commit -m first
  jj bookmark create work -r @-
  printf 'second change\n' > second.txt
  jj commit -m second
  tip=$(rev_of @- change_id)
}

check_project_only() {
  local dirty="$1" working bookmarks placed
  new_repo
  build_stack
  working=$(rev_of @ change_id)
  if [ "$dirty" = false ]; then
    jj bookmark create "$(rev_of "$project" commit_id)" -r base
    jj bookmark create "$(rev_of @ commit_id)" -r "$tip"
  fi
  bookmarks=$(bookmark_changes)

  if [ "$dirty" = true ]; then
    printf 'unsnapshotted work\n' > wip.txt
  fi
  jj-proj-tug --project-only

  assert_eq 'the working copy ends empty' '' "$(jj diff --summary -r @)"
  assert_eq 'the original project is the sole parent' "$project" "$(rev_of @- change_id)"
  assert_eq 'the project link survives the move' test-project-docs "$(readlink proj)"
  assert_eq 'the work below the project no longer contains the link' \
    $'base.txt\nfirst.txt\nsecond.txt' "$(jj file list -r "$tip")"
  assert_eq 'bookmarks stay on their original logical changes' "$bookmarks" "$(bookmark_changes)"

  if [ "$dirty" = true ]; then
    assert_eq 'the project follows the original dirty working change' "$working" "$(rev_of @-- change_id)"
    assert_eq 'work remains in the original change' 'A wip.txt' "$(jj diff --summary -r "$working")"
    assert_eq 'working content is preserved' 'unsnapshotted work' "$(jj file show -r "$working" wip.txt)"
  else
    assert_eq 'the empty working-copy change is reused' "$working" "$(rev_of @ change_id)"
    assert_eq 'the project follows the original work tip' "$tip" "$(rev_of @-- change_id)"
  fi

  placed=$(op_id)
  jj-proj-tug --project-only
  assert_eq 'the second call adds no operation' "$placed" "$(op_id)"
}

check_project_parent_with_dirty_work() {
  local work bookmarks
  new_repo
  add_project
  work=$(rev_of @ change_id)
  bookmarks=$(bookmark_changes)
  printf 'current edits\n' > wip.txt
  jj-proj-tug --project-only

  assert_eq 'a project already under dirty work still gets moved' "$work" "$(rev_of @-- change_id)"
  assert_eq 'the project comes after the original work' "$project" "$(rev_of @- change_id)"
  assert_eq 'a fresh working copy ends empty' '' "$(jj diff --summary -r @)"
  assert_eq 'original work retains its edits' 'current edits' "$(jj file show -r "$work" wip.txt)"
  assert_eq 'the branch behind the work does not advance' "$bookmarks" "$(bookmark_changes)"
}

check_refusal() {
  local explanation="$1" before rc=0
  before=$(op_id)
  jj-proj-tug --project-only >"$out/refusal.log" 2>&1 || rc=$?
  assert_false "refuses: $explanation" "$rc"
  assert_true "explains: $explanation" "$(grep -qF "$explanation" "$out/refusal.log"; echo $?)"
  assert_eq 'refusal leaves repository state unchanged' "$before" "$(op_id)"
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
jj -R "$out/shared-workspace" edit "$(rev_of @ change_id)"
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
old_working=$(rev_of @ change_id)
printf 'legacy dirty work\n' > wip.txt
jj-proj-tug
assert_eq 'legacy installs a fresh empty working copy' '' "$(jj diff --summary -r @)"
assert_eq 'legacy moves the branch to the previous working-copy change' "$old_working" "$(rev_of work change_id)"
assert_eq 'legacy puts the project on top of the branch' "$old_working" "$(rev_of @-- change_id)"
assert_eq 'legacy project is directly below the fresh working copy' "$project" "$(rev_of @- change_id)"
finish
