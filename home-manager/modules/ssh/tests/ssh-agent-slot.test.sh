# shellcheck shell=bash
# Regression suite for ssh-agent-slot. Usage: run <path-to-ssh-agent-slot>.
#
# Each scenario runs against its own fake $HOME. Live agents are real
# ssh-agent instances bound with -a: self-built layout-shaped paths
# ($fakehome/.ssh/agent/s.<hash>.sshd.<rand> — sshd tags forwarded sockets
# "sshd") stand in for forwarded
# sockets (default-layout sockets under a $TMPDIR-based fake home exceed
# macOS's 104-char Unix socket path limit), an arbitrary non-layout
# path stands in for the configured local agent, and a symlink to a layout-shaped
# socket stands in for herdr's (>= 0.9.2) stable agent address.
set -euo pipefail

script=${1:?usage: ssh-agent-slot.test.sh <path-to-ssh-agent-slot>}

pass=0
fail=0
pids=()
tmpdirs=()

cleanup() {
    local pid dir
    for pid in ${pids[@]+"${pids[@]}"}; do
        kill "$pid" 2>/dev/null || true
    done
    for dir in ${tmpdirs[@]+"${tmpdirs[@]}"}; do
        rm -rf -- "$dir"
    done
}
trap cleanup EXIT

ok() {
    pass=$((pass + 1))
    printf 'ok - %s\n' "$1"
}

bad() {
    fail=$((fail + 1))
    printf 'FAIL - %s\n' "$1" >&2
}

# New fake home with an empty .ssh/agent dir; prints the home path.
new_home() {
    local work home
    work=$(mktemp -d "${TMPDIR:-/tmp}/shs.XXXXXX")
    home="$work/home"
    mkdir -p -- "$home/.ssh/agent"
    tmpdirs+=("$work")
    printf '%s' "$home"
}

# Start a live ssh-agent bound to $1; prints the agent pid.
start_agent() {
    local output pid
    output=$(ssh-agent -a "$1" 2>&1) || {
        printf 'ssh-agent-slot.test: agent start failed: %s\n%s\n' "$1" "$output" >&2
        return 1
    }
    pid=$(awk -F';' '/^SSH_AGENT_PID/ {sub(/SSH_AGENT_PID=/, "", $1); print $1}' <<<"$output")
    [[ -n "$pid" ]] || {
        printf 'ssh-agent-slot.test: pid parse failed:\n%s\n' "$output" >&2
        return 1
    }
    pids+=("$pid")
    printf '%s' "$pid"
}

# Run the helper with a clean agent environment.
run() { # run <home> <local_socket> <args...>
    env -u SSH_CONNECTION -u SSH_AUTH_SOCK HOME="$1" local_socket="$2" bash "$script" "${@:3}"
}

# Run init, optionally with an incoming forwarded socket.
init_run() { # init_run <home> <local_socket> [incoming_socket]
    if [[ $# -ge 3 ]]; then
        env -u SSH_AUTH_SOCK HOME="$1" local_socket="$2" \
            SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" SSH_AUTH_SOCK="$3" \
            bash "$script" init
    else
        run "$1" "$2" init
    fi
}

link_of() {
    readlink -- "$1" 2>/dev/null || printf '<missing>'
}

# Assert a slot symlink points exactly at the expected target.
assert_link() { # assert_link <name> <slot> <expected>
    local actual
    actual=$(link_of "$2")
    if [[ "$actual" = "$3" ]]; then
        ok "$1"
    else
        bad "$1: $2 -> $actual, want $3"
    fi
}

# An inactive slot is absent, not a dangling symlink or another filesystem object.
assert_absent() { # assert_absent <name> <slot>
    if [[ ! -e "$2" && ! -L "$2" ]]; then
        ok "$1"
    else
        bad "$1: $2 exists or is a symlink"
    fi
}

# Run a command and assert its exit code.
expect_rc() { # expect_rc <name> <want> <cmd...>
    local rc=0
    "${@:3}" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq "$2" ]]; then
        ok "$1"
    else
        bad "$1: exit $rc, want $2"
    fi
}

# 1. Bootstrap with a local agent: fresh slots, live local socket.
t_bootstrap_local() {
    local home local_sock
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    init_run "$home" "$local_sock"
    assert_link "bootstrap(local): primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_absent "bootstrap(local): backup is absent" "$home/.ssh/ssh_auth_sock_b"
}

# 2. Bootstrap without a local agent: both slots are absent.
t_bootstrap_none() {
    local home
    home=$(new_home)
    init_run "$home" ""
    assert_absent "bootstrap(none): primary is absent" "$home/.ssh/ssh_auth_sock"
    assert_absent "bootstrap(none): backup is absent" "$home/.ssh/ssh_auth_sock_b"
    expect_rc "bootstrap(none): primary probe fails" 1 run "$home" "" probe "$home/.ssh/ssh_auth_sock"
    expect_rc "bootstrap(none): backup probe fails" 1 run "$home" "" probe "$home/.ssh/ssh_auth_sock_b"
    expect_rc "bootstrap(none): fixup has no agent" 1 run "$home" "" fixup
}

# 3. Stale live non-layout targets in both slots are replaced, no a = b.
t_stale_ineligible() {
    local home local_sock stale
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    stale="$home/launchd-standin"
    start_agent "$stale" >/dev/null
    ln -s -- "$stale" "$home/.ssh/ssh_auth_sock"
    ln -s -- "$stale" "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" "$local_sock"
    assert_link "stale: primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_absent "stale: backup is absent" "$home/.ssh/ssh_auth_sock_b"
}

# 3b. An a = b = local state self-heals to distinct slots.
t_same_target_local() {
    local home local_sock
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    ln -s -- "$local_sock" "$home/.ssh/ssh_auth_sock"
    ln -s -- "$local_sock" "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" "$local_sock"
    assert_link "a=b(local): primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_absent "a=b(local): backup is absent" "$home/.ssh/ssh_auth_sock_b"
}

# 4. An incoming forwarded socket promotes to primary; local moves to backup.
t_forwarded_promotion() {
    local home local_sock fwd
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    fwd="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$fwd" >/dev/null
    init_run "$home" "$local_sock" "$fwd"
    assert_link "forward: primary is forwarded" "$home/.ssh/ssh_auth_sock" "$fwd"
    assert_link "forward: backup is local" "$home/.ssh/ssh_auth_sock_b" "$local_sock"
}

# 5. Consecutive forwarded sessions: local stays in backup; after both die
# the dead primary stays and the probe fallback reaches local.
t_consecutive_forwarded() {
    local home local_sock f1 f2 p1 p2
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    p1=$(start_agent "$f1")
    init_run "$home" "$local_sock" "$f1"
    p2=$(start_agent "$f2")
    init_run "$home" "$local_sock" "$f2"
    assert_link "consecutive: primary is second" "$home/.ssh/ssh_auth_sock" "$f2"
    assert_link "consecutive: backup is local, not first" "$home/.ssh/ssh_auth_sock_b" "$local_sock"
    kill "$p1" "$p2" 2>/dev/null
    sleep 0.3
    init_run "$home" "$local_sock"
    assert_link "consecutive: dead primary kept" "$home/.ssh/ssh_auth_sock" "$f2"
    assert_link "consecutive: backup still local" "$home/.ssh/ssh_auth_sock_b" "$local_sock"
    expect_rc "consecutive: probe dead primary fails" 1 run "$home" "$local_sock" probe "$home/.ssh/ssh_auth_sock"
    expect_rc "consecutive: probe backup local succeeds" 0 run "$home" "$local_sock" probe "$home/.ssh/ssh_auth_sock_b"
}

# 6. Without a local agent, rotation keeps the previous forwarded socket.
t_rotation_no_local() {
    local home f1 f2 p1 p2
    home=$(new_home)
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    p1=$(start_agent "$f1")
    init_run "$home" "" "$f1"
    assert_link "rotation: primary is first" "$home/.ssh/ssh_auth_sock" "$f1"
    assert_absent "rotation: backup is absent" "$home/.ssh/ssh_auth_sock_b"
    p2=$(start_agent "$f2")
    init_run "$home" "" "$f2"
    assert_link "rotation: primary is second" "$home/.ssh/ssh_auth_sock" "$f2"
    assert_link "rotation: backup is first" "$home/.ssh/ssh_auth_sock_b" "$f1"
    kill "$p1" "$p2" 2>/dev/null
    sleep 0.3
    init_run "$home" ""
    assert_link "rotation: dead slots kept after death" "$home/.ssh/ssh_auth_sock" "$f2"
    assert_link "rotation: dead backup kept after death" "$home/.ssh/ssh_auth_sock_b" "$f1"
}

# 7. Primary = local steady state is idempotent; a dead layout-shaped
# backup is preserved (eligible layouts are not sanitized).
t_steady_state() {
    local home local_sock dead_f pd
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    ln -s -- "$local_sock" "$home/.ssh/ssh_auth_sock"
    ln -s -- /dev/null "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" "$local_sock"
    assert_link "steady: primary unchanged" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_absent "steady: legacy backup is cleared" "$home/.ssh/ssh_auth_sock_b"
    dead_f="$home/.ssh/agent/s.hd.sshd.rd"
    pd=$(start_agent "$dead_f")
    kill "$pd" 2>/dev/null
    sleep 0.3
    ln -sf -- "$dead_f" "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" "$local_sock"
    assert_link "steady: dead layout backup kept" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_link "steady: dead layout backup kept (b)" "$home/.ssh/ssh_auth_sock_b" "$dead_f"
}

# 8. A non-symlink slot is refused with a message and left untouched.
t_non_symlink_guard() {
    local home local_sock
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    printf 'x' >"$home/.ssh/ssh_auth_sock"
    local output rc=0
    output=$(run "$home" "$local_sock" init 2>&1) || rc=$?
    if [[ "$rc" -eq 1 && "$output" == *"not a symlink"* ]]; then
        ok "guard: non-symlink primary refused"
    else
        bad "guard: non-symlink primary refused (rc=$rc, output=$output)"
    fi
    if [[ -f "$home/.ssh/ssh_auth_sock" && "$(cat "$home/.ssh/ssh_auth_sock")" = x ]]; then
        ok "guard: file left untouched"
    else
        bad "guard: file left untouched"
    fi
}

# 9. fixup promotes a responsive local backup over a dead layout primary;
# fixup --local dies without a configured local socket.
t_fixup() {
    local home local_sock dead_f pd
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    dead_f="$home/.ssh/agent/s.hd.sshd.rd"
    pd=$(start_agent "$dead_f")
    kill "$pd" 2>/dev/null
    sleep 0.3
    ln -s -- "$dead_f" "$home/.ssh/ssh_auth_sock"
    ln -s -- "$local_sock" "$home/.ssh/ssh_auth_sock_b"
    expect_rc "fixup: exit 0" 0 run "$home" "$local_sock" fixup
    assert_link "fixup: primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_link "fixup: backup is old primary" "$home/.ssh/ssh_auth_sock_b" "$dead_f"
    expect_rc "fixup --local: dies without local socket" 1 run "$home" "" fixup --local
}

# 10. A local ssh-agent layout socket (tag "agent") is not treated as
# forwarded and is never promoted.
t_local_agent_layout() {
    local home local_sock local_agent
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    local_agent="$home/.ssh/agent/s.ha.agent.ra"
    start_agent "$local_agent" >/dev/null
    init_run "$home" "$local_sock"
    assert_link "local-agent: primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    init_run "$home" "$local_sock" "$local_agent"
    assert_link "local-agent: not promoted as forwarded" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_absent "local-agent: backup stays absent" "$home/.ssh/ssh_auth_sock_b"
}

# 11. A herdr stable-address symlink to a live forwarded socket promotes like the raw
# socket: primary tracks the link, configured local socket moves to backup.
t_herdr_link_promotion() {
    local home local_sock fwd link
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    fwd="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$fwd" >/dev/null
    link="$home/.config/herdr/herdr.sock.agent"
    mkdir -p -- "$home/.config/herdr"
    ln -s -- "$fwd" "$link"
    init_run "$home" "$local_sock" "$link"
    assert_link "herdr-link: primary is the link" "$home/.ssh/ssh_auth_sock" "$link"
    assert_link "herdr-link: backup is local" "$home/.ssh/ssh_auth_sock_b" "$local_sock"
}

# 12. Herdr retargets the link between init runs: the slot keeps the link and resolves
# the new target; the probe fails once the target dies.
t_herdr_link_retarget() {
    local home link f1 f2 p1 p2
    home=$(new_home)
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    p1=$(start_agent "$f1")
    link="$home/.config/herdr/herdr.sock.agent"
    mkdir -p -- "$home/.config/herdr"
    ln -s -- "$f1" "$link"
    init_run "$home" "" "$link"
    assert_link "herdr-retarget: primary is the link" "$home/.ssh/ssh_auth_sock" "$link"
    p2=$(start_agent "$f2")
    ln -sfn -- "$f2" "$link"
    init_run "$home" "" "$link"
    assert_link "herdr-retarget: primary stays the link" "$home/.ssh/ssh_auth_sock" "$link"
    expect_rc "herdr-retarget: probe resolves new target" 0 run "$home" "" probe "$home/.ssh/ssh_auth_sock"
    kill "$p1" "$p2" 2>/dev/null
    sleep 0.3
    expect_rc "herdr-retarget: probe fails after agent death" 1 run "$home" "" probe "$home/.ssh/ssh_auth_sock"
}

# 13. A link to a live non-layout socket (herdr unavailable marker or arbitrary agent)
# is never promoted; the slots are left untouched.
t_herdr_link_unavailable() {
    local home local_sock other link
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    init_run "$home" "$local_sock"
    mkdir -p -- "$home/.config/herdr"
    other="$home/.config/herdr/other.sock"
    start_agent "$other" >/dev/null
    link="$home/.config/herdr/herdr.sock.agent"
    ln -s -- "$other" "$link"
    init_run "$home" "$local_sock" "$link"
    assert_link "herdr-unavailable: primary untouched" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_absent "herdr-unavailable: backup stays absent" "$home/.ssh/ssh_auth_sock_b"
}

# 14. A dangling link (target removed, as when the herdr server stops) is never
# promoted.
t_herdr_link_dangling() {
    local home local_sock fwd link pd
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    init_run "$home" "$local_sock"
    fwd="$home/.ssh/agent/s.h9.sshd.r9"
    pd=$(start_agent "$fwd")
    link="$home/.config/herdr/herdr.sock.agent"
    mkdir -p -- "$home/.config/herdr"
    ln -s -- "$fwd" "$link"
    kill "$pd" 2>/dev/null
    rm -f -- "$fwd"
    sleep 0.3
    init_run "$home" "$local_sock" "$link"
    assert_link "herdr-dangling: primary untouched" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_absent "herdr-dangling: backup stays absent" "$home/.ssh/ssh_auth_sock_b"
}

# Legacy placeholders are migrated without discarding a usable backup.
t_legacy_placeholders() {
    local home fwd
    home=$(new_home)
    ln -s -- /dev/null "$home/.ssh/ssh_auth_sock"
    ln -s -- /dev/null "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" ""
    assert_absent "legacy: primary cleared" "$home/.ssh/ssh_auth_sock"
    assert_absent "legacy: backup cleared" "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" ""
    assert_absent "legacy: repeated init keeps primary absent" "$home/.ssh/ssh_auth_sock"
    assert_absent "legacy: repeated init keeps backup absent" "$home/.ssh/ssh_auth_sock_b"

    fwd="$home/.ssh/agent/s.legacy.sshd.backup"
    start_agent "$fwd" >/dev/null
    ln -sfn -- /dev/null "$home/.ssh/ssh_auth_sock"
    ln -sfn -- "$fwd" "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" ""
    assert_absent "legacy: mixed primary cleared" "$home/.ssh/ssh_auth_sock"
    assert_link "legacy: mixed backup preserved" "$home/.ssh/ssh_auth_sock_b" "$fwd"
}

# Herdr becoming unavailable clears only the primary; explicit fixup restores backup.
t_herdr_unavailable_transition() {
    local home fwd current link
    home=$(new_home)
    fwd="$home/.ssh/agent/s.previous.sshd.backup"
    current="$home/.ssh/agent/s.current.sshd.herdr"
    start_agent "$fwd" >/dev/null
    start_agent "$current" >/dev/null
    init_run "$home" "" "$fwd"
    link="$home/.config/herdr/herdr.sock.agent"
    mkdir -p -- "$home/.config/herdr"
    ln -s -- "$current" "$link"
    init_run "$home" "" "$link"
    assert_link "herdr-transition: primary tracks stable link" "$home/.ssh/ssh_auth_sock" "$link"
    assert_link "herdr-transition: old forward is backup" "$home/.ssh/ssh_auth_sock_b" "$fwd"
    ln -sfn -- "$home/.config/herdr/herdr.sock.unavailable" "$link"
    init_run "$home" "" "$link"
    assert_absent "herdr-transition: unavailable primary cleared" "$home/.ssh/ssh_auth_sock"
    assert_link "herdr-transition: backup preserved" "$home/.ssh/ssh_auth_sock_b" "$fwd"
    expect_rc "herdr-transition: explicit fixup succeeds" 0 run "$home" "" fixup
    assert_link "herdr-transition: fixup promotes backup" "$home/.ssh/ssh_auth_sock" "$fwd"
    assert_absent "herdr-transition: promoted backup is cleared" "$home/.ssh/ssh_auth_sock_b"
}

t_bootstrap_local
t_bootstrap_none
t_stale_ineligible
t_same_target_local
t_forwarded_promotion
t_consecutive_forwarded
t_rotation_no_local
t_steady_state
t_non_symlink_guard
t_fixup
t_local_agent_layout

t_herdr_link_promotion
t_herdr_link_retarget
t_herdr_link_unavailable
t_herdr_link_dangling
t_legacy_placeholders
t_herdr_unavailable_transition

printf 'ssh-agent-slot.test: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
