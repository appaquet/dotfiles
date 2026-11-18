# Behavioral suite for the jj-promote command.
#
# jj-promote promotes agent-authored jujutsu changes by stripping the `unreviewed: `
# description prefix. The previous `private: agent: ` / `private: claude: ` prefixes are
# recognized too and stripped the same way, with no prompt and no stdin read. Stripping a
# prefix moves the change outside the private() revset, making it pushable.
#
# The suite builds throwaway jj repositories, runs the command under test, and asserts
# resulting descriptions byte-exactly plus repository-level effects (dry-run leaves no
# operation, re-runs are no-ops, unknown revsets fail loudly).

# private_of <repo> <change-id>  -> "private"/"public" whether the change is still in private()
private_of() {
  if [ -n "$(rev_of "private() & $2" 'description.first_line()' -R "$1")" ]; then
    echo "private"
  else
    echo "public"
  fi
}

# new_repo -> prints a fresh repo dir seeded with a master bookmark holding one commit
new_repo() {
  local repo
  repo=$(init_repo) || return 1
  (
    cd "$repo" || exit 1
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

echo "== jj-promote suite =="

# --- Case: single-line new-prefix change, explicit revset -------------------------
repo=$(new_repo) || { echo "FATAL: repo setup failed" >&2; exit 1; }
add_change "$repo" -m 'unreviewed: feat(home): add example command'
cid_single=$(rev_of '@-' change_id -R "$repo")
(cd "$repo" && jj-promote "$cid_single" >"$out/out.log" 2>&1); rc=$?
assert_true "single-line promote exits 0" "$rc"
assert_eq "single-line new prefix stripped to conventional form" \
  'feat(home): add example command' \
  "$(rev_of "$cid_single" description -R "$repo")"
assert_eq "single-line change left private()" \
  "public" "$(private_of "$repo" "$cid_single")"

# --- Case: multiline new-prefix change keeps its body byte-exact ------------------
add_change "$repo" -m 'unreviewed: fix(nix): guard workspace delete' -m 'body line one
body line two'
cid_multi=$(rev_of '@-' change_id -R "$repo")
(cd "$repo" && jj-promote "$cid_multi" >"$out/out.log" 2>&1); rc=$?
assert_true "multiline promote exits 0" "$rc"
assert_eq "multiline description keeps body byte-exact minus prefix" \
  'fix(nix): guard workspace delete

body line one
body line two' \
  "$(rev_of "$cid_multi" description -R "$repo")"

# --- Case: new-prefix-only description is skipped ----------------------------------
add_change "$repo" -m 'unreviewed: '
cid_prefixonly=$(rev_of '@-' change_id -R "$repo")
before_prefixonly=$(rev_of "$cid_prefixonly" description -R "$repo")
(cd "$repo" && jj-promote "$cid_prefixonly" >"$out/out.log" 2>&1); rc=$?
assert_true "new-prefix-only skip run exits 0" "$rc"
assert_eq "new-prefix-only description untouched" "$before_prefixonly" "$(rev_of "$cid_prefixonly" description -R "$repo")"

# --- Case: legacy agent prefix stripped without prompting --------------------------
add_change "$repo" -m 'private: agent: docs(readme): refresh cheat sheet'
cid_agent=$(rev_of '@-' change_id -R "$repo")
(cd "$repo" && jj-promote "$cid_agent" </dev/null >"$out/out.log" 2>&1); rc=$?
assert_true "legacy agent promote exits 0 with stdin closed" "$rc"
assert_eq "legacy agent prefix stripped without prompting" \
  'docs(readme): refresh cheat sheet' \
  "$(rev_of "$cid_agent" description -R "$repo")"
assert_eq "legacy agent change left private()" \
  "public" "$(private_of "$repo" "$cid_agent")"
prompt_hits=$(grep -c 'previous format\|Strip them too' "$out/out.log" || true)
assert_eq "legacy agent strip prints no prompt text" "0" "$prompt_hits"

# --- Case: legacy claude prefix stripped without prompting -------------------------
add_change "$repo" -m 'private: claude: chore(ci): tune check job'
cid_claude=$(rev_of '@-' change_id -R "$repo")
(cd "$repo" && jj-promote "$cid_claude" </dev/null >"$out/out.log" 2>&1); rc=$?
assert_true "legacy claude promote exits 0 with stdin closed" "$rc"
assert_eq "legacy claude prefix stripped without prompting" \
  'chore(ci): tune check job' \
  "$(rev_of "$cid_claude" description -R "$repo")"
assert_eq "legacy claude change left private()" \
  "public" "$(private_of "$repo" "$cid_claude")"


# --- Case: protected and unrelated descriptions are skipped ------------------------
add_change "$repo" -m 'private: proj - some-project'
cid_proj=$(rev_of '@-' change_id -R "$repo")
add_change "$repo" -m 'private: scratch note'
cid_scratch=$(rev_of '@-' change_id -R "$repo")
add_change "$repo" -m 'feat(already): public change'
cid_public=$(rev_of '@-' change_id -R "$repo")

revset="$cid_proj | $cid_scratch | $cid_public"
before_proj=$(rev_of "$cid_proj" description -R "$repo")
before_scratch=$(rev_of "$cid_scratch" description -R "$repo")
before_public=$(rev_of "$cid_public" description -R "$repo")
(cd "$repo" && jj-promote "$revset" >"$out/out.log" 2>&1)
rc=$?
assert_true "skip-only run exits 0" "$rc"
assert_eq "proj commit description untouched" "$before_proj" "$(rev_of "$cid_proj" description -R "$repo")"
assert_eq "scratch private description untouched" "$before_scratch" "$(rev_of "$cid_scratch" description -R "$repo")"
assert_eq "already-public description untouched" "$before_public" "$(rev_of "$cid_public" description -R "$repo")"

# --- Case: mixed run strips both prefix families without prompting -----------------
add_change "$repo" -m 'unreviewed: feat(shell): new pending work'
cid_mixed_new=$(rev_of '@-' change_id -R "$repo")
add_change "$repo" -m 'private: agent: fix(shell): legacy pending work'
cid_mixed_legacy=$(rev_of '@-' change_id -R "$repo")
(cd "$repo" && jj-promote "$cid_mixed_new | $cid_mixed_legacy" </dev/null >"$out/out.log" 2>&1); rc=$?
assert_true "mixed run exits 0 with stdin closed" "$rc"
assert_eq "mixed run strips the unreviewed change" \
  'feat(shell): new pending work' \
  "$(rev_of "$cid_mixed_new" description -R "$repo")"
assert_eq "mixed run strips the legacy change" \
  'fix(shell): legacy pending work' \
  "$(rev_of "$cid_mixed_legacy" description -R "$repo")"
assert_eq "mixed run leaves both changes public" \
  "public public" "$(private_of "$repo" "$cid_mixed_new") $(private_of "$repo" "$cid_mixed_legacy")"

# --- Case: default revset promotes new-prefix changes above trunk ------------------
add_change "$repo" -m 'unreviewed: chore(ci): tune check job'
add_change "$repo" -m 'unreviewed: perf(shell): speed up prompt'
cid_agent_a=$(rev_of '@--' change_id -R "$repo")
cid_agent_b=$(rev_of '@-' change_id -R "$repo")
(cd "$repo" && jj-promote >"$out/out.log" 2>&1); rc=$?
assert_true "bare invoke exits 0" "$rc"
assert_eq "bare invoke promotes new-prefix change A via default revset" \
  'chore(ci): tune check job' \
  "$(rev_of "$cid_agent_a" description -R "$repo")"
assert_eq "bare invoke promotes new-prefix change B via default revset" \
  'perf(shell): speed up prompt' \
  "$(rev_of "$cid_agent_b" description -R "$repo")"
assert_eq "proj commit still skipped after bare invoke" "$before_proj" "$(rev_of "$cid_proj" description -R "$repo")"
assert_eq "scratch private still skipped after bare invoke" "$before_scratch" "$(rev_of "$cid_scratch" description -R "$repo")"

# --- Case: default revset promotes legacy changes above trunk without --yes --------
add_change "$repo" -m 'private: agent: chore(ci): legacy tune'
add_change "$repo" -m 'private: agent: perf(shell): legacy speedup'
cid_legacy_a=$(rev_of '@--' change_id -R "$repo")
cid_legacy_b=$(rev_of '@-' change_id -R "$repo")
(cd "$repo" && jj-promote </dev/null >"$out/out.log" 2>&1); rc=$?
assert_true "bare invoke with legacy changes exits 0" "$rc"
assert_eq "bare invoke promotes legacy change A" \
  'chore(ci): legacy tune' \
  "$(rev_of "$cid_legacy_a" description -R "$repo")"
assert_eq "bare invoke promotes legacy change B" \
  'perf(shell): legacy speedup' \
  "$(rev_of "$cid_legacy_b" description -R "$repo")"

# --- Case: bare invoke leaves commits at or below trunk untouched ------------------
# trunk() is the master@origin remote bookmark, so a published commit sits outside
# trunk()..@ and must never be swept by a bare invoke. This pins the blast radius of
# the default revset: the remote is only created here, after the earlier cases ran.
add_change "$repo" -m 'private: agent: fix(trunk): buried on mainline'
cid_buried=$(rev_of '@-' change_id -R "$repo")
git init --bare "$out/upstream.git" >/dev/null 2>&1
(cd "$repo" && jj git remote add upstream "$out/upstream.git" >/dev/null 2>&1); rc=$?
assert_true "adding a remote to the test repo succeeds" "$rc"
(cd "$repo" && jj bookmark set master -r "$cid_buried" >/dev/null 2>&1); rc=$?
assert_true "moving the trunk bookmark onto the agent commit succeeds" "$rc"
(cd "$repo" && jj git push --allow-private -b master >/dev/null 2>&1); rc=$?
assert_true "publishing the trunk bookmark succeeds" "$rc"
(cd "$repo" && jj-promote </dev/null >"$out/out.log" 2>&1); rc=$?
assert_true "bare invoke with trunk at an agent commit exits 0" "$rc"
assert_eq "agent commit at trunk stays out of the default trunk()..@ range" \
  'private: agent: fix(trunk): buried on mainline' \
  "$(rev_of "$cid_buried" description -R "$repo")"

# --- Case: re-run after promotion is a no-op ---------------------------------------
op_before=$(op_id -R "$repo")
(cd "$repo" && jj-promote >"$out/out2.log" 2>&1); rc=$?
assert_true "re-run exits 0" "$rc"
op_after=$(op_id -R "$repo")
assert_eq "re-run creates no mutation" "$op_before" "$op_after"

# --- Case: --dry-run reports without mutating --------------------------------------
add_change "$repo" -m 'unreviewed: refactor(vcs): extract helper'
cid_dry=$(rev_of '@-' change_id -R "$repo")
before_dry=$(rev_of "$cid_dry" description -R "$repo")
op_before=$(op_id -R "$repo")
(cd "$repo" && jj-promote --dry-run "$cid_dry" >"$out/out3.log" 2>&1); rc=$?
assert_true "dry-run exits 0" "$rc"
assert_eq "dry-run leaves description untouched" "$before_dry" "$(rev_of "$cid_dry" description -R "$repo")"
op_after=$(op_id -R "$repo")
assert_eq "dry-run creates no mutation" "$op_before" "$op_after"

# --- Case: --dry-run with legacy in scope does not block or mutate ------------------
add_change "$repo" -m 'private: agent: refactor(vcs): legacy helper'
cid_dry_legacy=$(rev_of '@-' change_id -R "$repo")
before_dry_legacy=$(rev_of "$cid_dry_legacy" description -R "$repo")
op_before=$(op_id -R "$repo")
(cd "$repo" && jj-promote --dry-run "$cid_dry_legacy" </dev/null >"$out/out4.log" 2>&1); rc=$?
assert_true "dry-run with legacy exits 0 without a TTY" "$rc"
assert_eq "dry-run with legacy leaves description untouched" \
  "$before_dry_legacy" "$(rev_of "$cid_dry_legacy" description -R "$repo")"
op_after=$(op_id -R "$repo")
assert_eq "dry-run with legacy creates no mutation" "$op_before" "$op_after"
would_hits=$(grep -cE '^would promote  [a-z0-9]{12}  private: agent: refactor\(vcs\): legacy helper  ->  refactor\(vcs\): legacy helper$' "$out/out4.log" || true)
assert_eq "dry-run reports the legacy change with the plain would-promote line" "1" "$would_hits"
prompt_hits=$(grep -c 'previous format\|confirm at write time' "$out/out4.log" || true)
assert_eq "dry-run prints no previous-format wording" "0" "$prompt_hits"

# --- Case: the removed --yes flag is rejected --------------------------------------
add_change "$repo" -m 'private: agent: refactor(vcs): rejected flag'
cid_yes=$(rev_of '@-' change_id -R "$repo")
before_yes=$(rev_of "$cid_yes" description -R "$repo")
(cd "$repo" && jj-promote --yes "$cid_yes" >"$out/out-yes.log" 2>&1); rc=$?
assert_false "removed --yes flag exits non-zero" "$rc"
grep -q "unknown option '--yes'" "$out/out-yes.log" \
  && pass "--yes rejection reports the unknown option" \
  || fail "--yes rejection reports the unknown option" "$(cat "$out/out-yes.log")"
assert_eq "--yes rejection leaves the description untouched" \
  "$before_yes" "$(rev_of "$cid_yes" description -R "$repo")"

# --- Case: unknown revset fails loudly ----------------------------------------------
(cd "$repo" && jj-promote 'this is not a revset((' >/dev/null 2>&1); rc=$?
assert_false "invalid revset exits non-zero" "$rc"
finish
