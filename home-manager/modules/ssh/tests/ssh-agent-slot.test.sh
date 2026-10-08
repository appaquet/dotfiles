# shellcheck shell=bash
# Regression suite for ssh-agent-slot. Usage: run <path-to-ssh-agent-slot>.
#
# Each scenario runs against its own fake $HOME. Live agents are real
# ssh-agent instances bound with -a: self-built layout-shaped paths
# ($fakehome/.ssh/agent/s.<hash>.sshd.<rand> — sshd tags forwarded sockets
# "sshd") stand in for forwarded
# sockets (default-layout sockets under a $TMPDIR-based fake home exceed
# macOS's 104-char Unix socket path limit), and an arbitrary non-layout
# path stands in for the configured local agent.
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
    assert_link "bootstrap(local): backup is placeholder" "$home/.ssh/ssh_auth_sock_b" /dev/null
}

# 2. Bootstrap without a local agent: both slots are placeholders.
t_bootstrap_none() {
    local home
    home=$(new_home)
    init_run "$home" ""
    assert_link "bootstrap(none): primary is placeholder" "$home/.ssh/ssh_auth_sock" /dev/null
    assert_link "bootstrap(none): backup is placeholder" "$home/.ssh/ssh_auth_sock_b" /dev/null
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
    assert_link "stale: backup is placeholder" "$home/.ssh/ssh_auth_sock_b" /dev/null
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
    assert_link "a=b(local): backup is placeholder" "$home/.ssh/ssh_auth_sock_b" /dev/null
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
    assert_link "rotation: backup is placeholder" "$home/.ssh/ssh_auth_sock_b" /dev/null
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
    assert_link "steady: backup unchanged" "$home/.ssh/ssh_auth_sock_b" /dev/null
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
    assert_link "local-agent: backup untouched" "$home/.ssh/ssh_auth_sock_b" /dev/null
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

printf 'ssh-agent-slot.test: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
