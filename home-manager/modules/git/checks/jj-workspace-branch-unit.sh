# Behavioral suite for the jj-workspace-branch command.
#
# The workspace bookmark follows the nearest non-empty, non-private change.
# A bookmark parked on a private change and the default workspace are exempt.
#
# The suite builds throwaway jj repositories with a second workspace, runs the
# command under test, and asserts the resulting bookmarks, messages, and exit
# codes.

# bookmark_target <repo> <name> -> commit id the local bookmark points at (empty if absent)
bookmark_target() {
  rev_of "bookmarks(exact:\"$2\")" commit_id -R "$1"
}

# new_repo [empty] -> fresh repo with a ws-a workspace and an optional content commit.
new_repo() {
  local repo
  repo=$(init_repo) || return 1
  (
    cd "$repo" || exit 1
    if [ "$#" -eq 0 ]; then
      printf 'content\n' > file.txt
      jj commit -m init >/dev/null || exit 1
    fi
    jj workspace add --name ws-a "$repo/ws-a" >/dev/null || exit 1
  ) >&2 || return 1
  printf '%s\n' "$repo"
}

echo "== jj-workspace-branch suite =="

repo=$(new_repo) || { echo "FATAL: repo setup failed" >&2; exit 1; }

ws="$repo/ws-a"
rev_id() {
  rev_of "$1" commit_id -R "$ws"
}

run_branch() {
  (cd "$ws" && jj-workspace-branch >"$out/branch.log" 2>&1)
}

# An empty working copy above content and private changes selects the content.
base=$(rev_id @-)
(
  cd "$ws" || exit 1
  jj bookmark create ws-a-other -r @- || exit 1
  printf 'private notes\n' > notes.txt
  jj commit -m 'private: notes' || exit 1
  jj new -m 'empty spacer' || exit 1
) >&2 || exit 1
run_branch; rc=$?
assert_true "create run exits 0" "$rc"
assert_eq "create skips empty and non-empty private changes" "$base" "$(bookmark_target "$repo" ws-a)"
run_branch; rc=$?
assert_true "re-run exits 0" "$rc"
assert_eq "re-run keeps the same eligible target" "$base" "$(bookmark_target "$repo" ws-a)"

# Unsnapshotted edits qualify @ even though the previous snapshot was empty.
printf 'work in progress\n' > "$ws/work.txt"
run_branch; rc=$?
assert_true "re-run with unsnapshotted work exits 0" "$rc"
work=$(rev_id @)
assert_eq "bookmark advances to the newly snapshotted @" "$work" "$(bookmark_target "$repo" ws-a)"
assert_eq "unsnapshotted work is part of the bookmark target" "work in progress" \
  "$(cd "$ws" && jj --ignore-working-copy file show -r ws-a work.txt 2>/dev/null)"
assert_eq "similarly named bookmark stays at base" "$base" "$(bookmark_target "$repo" ws-a-other)"

# A bookmark ahead of the eligible revision can be pulled back.
(
  cd "$ws" || exit 1
  jj new -m ahead || exit 1
  printf 'ahead\n' > ahead.txt
  jj bookmark set ws-a -r @ || exit 1
  jj edit "$work" || exit 1
) >&2 || exit 1
run_branch; rc=$?
assert_true "backwards run exits 0" "$rc"
assert_eq "bookmark moves backwards to eligible @" "$work" "$(bookmark_target "$repo" ws-a)"

# --- Case: a bookmark parked on a private change is never moved ----------------------------
# The bookmark's target carries a "private:" description and the working copy
# has advanced past it: the run must leave the bookmark where it is.
(
  cd "$repo/ws-a" || exit 1
  jj describe -m "private: parked work" >/dev/null 2>&1 || exit 1
  jj new -m next >/dev/null 2>&1 || exit 1
) >&2
private_commit=$(bookmark_target "$repo" ws-a)
( cd "$repo/ws-a" && jj-workspace-branch >"$out/out5.log" 2>&1 ); rc=$?
assert_true "private-parked run exits 0" "$rc"
assert_eq "private-parked bookmark stays on its target" \
  "$private_commit" "$(bookmark_target "$repo" ws-a)"
grep -q "parked on a private change" "$out/out5.log" \
  && pass "private-parked run reports the exemption" \
  || fail "private-parked run reports the exemption" "$(cat "$out/out5.log")"

# --- Case: the default workspace is rejected ---------------------------------------------
( cd "$repo" && jj-workspace-branch >"$out/out6.log" 2>&1 ); rc=$?
assert_false "default workspace run exits non-zero" "$rc"
assert_eq "default workspace run creates no bookmark" \
  "" "$(bookmark_target "$repo" default)"
grep -q "default workspace" "$out/out6.log" \
  && pass "default workspace run reports the refusal" \
  || fail "default workspace run reports the refusal" "$(cat "$out/out6.log")"

# --- Case: extra arguments are rejected ----------------------------------------------------
before_usage=$(bookmark_target "$repo" ws-a)
( cd "$repo/ws-a" && jj-workspace-branch surprise >"$out/out7.log" 2>&1 ); rc=$?
assert_false "extra argument exits non-zero" "$rc"
assert_eq "usage error leaves the bookmark untouched" \
  "$before_usage" "$(bookmark_target "$repo" ws-a)"

# No target in a repository whose only changes are empty.
repo=$(new_repo empty) || exit 1
ws="$repo/ws-a"
run_branch; rc=$?
assert_false "all-empty history is rejected" "$rc"
assert_eq "no bookmark is created in all-empty history" "" "$(bookmark_target "$repo" ws-a)"

# Two incomparable non-empty parents are ambiguous, not timestamp-tiebroken.
repo=$(new_repo) || exit 1
ws="$repo/ws-a"
base=$(rev_id @-)
(
  cd "$ws" || exit 1
  printf 'one\n' > one.txt
  jj commit -m one || exit 1
  one=$(jj log --no-graph -r @- -T 'commit_id') || exit 1
  jj new "$base" || exit 1
  printf 'two\n' > two.txt
  jj commit -m two || exit 1
  jj new "$one" @- || exit 1
) >&2 || exit 1
run_branch; rc=$?
assert_false "ambiguous history is rejected on create" "$rc"
assert_eq "ambiguous history creates no bookmark" "" "$(bookmark_target "$repo" ws-a)"
(cd "$ws" && jj bookmark set ws-a -r "$base" --allow-backwards) >&2 || exit 1
run_branch; rc=$?
assert_false "ambiguous history is rejected on update" "$rc"
assert_eq "ambiguous history preserves existing bookmark" "$base" "$(bookmark_target "$repo" ws-a)"

# A bookmark named like the selected hash does not redirect creation.
repo=$(new_repo) || exit 1
ws="$repo/ws-a"
base=$(rev_id @-)
(cd "$ws" && jj bookmark create "$base" -r @) >&2 || exit 1
run_branch; rc=$?
assert_true "hash-name collision run exits 0" "$rc"
assert_eq "new bookmark points at the commit, not the hash-named bookmark" \
  "$base" "$(bookmark_target "$repo" ws-a)"

# A Git update can park an existing bookmark before JJ imports the new target.
repo=$(new_repo) || exit 1
ws="$repo/ws-a"
base=$(rev_id @-)
(
  cd "$ws" || exit 1
  jj bookmark create ws-a -r "$base" || exit 1
  printf 'private content\n' > private.txt
  jj commit -m 'private: parked' || exit 1
  private=$(rev_id @-) || exit 1
  printf 'later work\n' > later.txt
  jj commit -m later || exit 1
  git update-ref refs/heads/ws-a "$private" || exit 1
) >&2 || exit 1
run_branch; rc=$?
assert_true "imported private bookmark run exits 0" "$rc"
assert_eq "bookmark imported onto private content is not moved back off it" \
  "$(rev_id 'description(glob:"private: parked*")')" "$(bookmark_target "$repo" ws-a)"

finish
