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
# socket stands in for herdr's (>= 0.9.2) stable agent link, which is never an
# entry. A SIGKILLed
# agent leaves its socket file behind with nothing listening (hung agent).
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

# Run init for a non-interactive session with an incoming forwarded socket.
init_run_ni() { # init_run_ni <home> <local_socket> <incoming_socket>
    env -u SSH_AUTH_SOCK HOME="$1" local_socket="$2" \
        SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" SSH_AUTH_SOCK="$3" \
        bash "$script" init --non-interactive
}

link_of() {
    readlink -- "$1" 2>/dev/null || printf '<missing>'
}

# Session stack targets, newest first, space-separated.
stack_of() { # stack_of <home>
    local -a names=()
    local i out=""
    shopt -s nullglob
    names=("$1"/.ssh/agent-sessions/*)
    shopt -u nullglob
    for (( i = ${#names[@]} - 1; i >= 0; i-- )); do
        out+="${out:+ }$(readlink -- "${names[i]}")"
    done
    printf '%s' "$out"
}

# Assert the exact session stack, newest first.
assert_stack() { # assert_stack <name> <home> [targets...]
    local actual want="${*:3}"
    actual=$(stack_of "$2")
    if [[ "$actual" = "$want" ]]; then
        ok "$1"
    else
        bad "$1: stack [$actual], want [$want]"
    fi
}

# Stop an agent and remove its socket, as sshd does on disconnect.
disconnect() { # disconnect <pid> <socket>
    kill "$1" 2>/dev/null || true
    sleep 0.2
    rm -f -- "$2"
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

# Bootstrap with a local agent: primary is local, stack empty.
t_bootstrap_local() {
    local home local_sock
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    init_run "$home" "$local_sock"
    assert_link "bootstrap(local): primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_stack "bootstrap(local): stack empty" "$home"
    if [[ -d "$home/.ssh/agent-sessions" ]]; then ok "bootstrap(local): sessions dir created"; else bad "bootstrap(local): sessions dir created"; fi
}

# Without a local agent nothing is selected and fixup has nothing to offer.
t_bootstrap_none() {
    local home
    home=$(new_home)
    init_run "$home" ""
    assert_absent "bootstrap(none): primary is absent" "$home/.ssh/ssh_auth_sock"
    expect_rc "bootstrap(none): fixup has no agent" 1 run "$home" "" fixup
}

# The configured local agent is selected even while its socket is missing.
t_local_missing_selected() {
    local home
    home=$(new_home)
    init_run "$home" "$home/local.sock"
    assert_link "local(missing): primary is local" "$home/.ssh/ssh_auth_sock" "$home/local.sock"
}

# Sessions stack newest-first; popping the newest falls back to the older one, then local.
t_push_pop_newest() {
    local home local_sock f1 f2
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    start_agent "$f1" >/dev/null
    start_agent "$f2" >/dev/null
    init_run "$home" "$local_sock" "$f1"
    assert_link "push: primary is first session" "$home/.ssh/ssh_auth_sock" "$f1"
    init_run "$home" "$local_sock" "$f2"
    assert_link "push: primary is newest session" "$home/.ssh/ssh_auth_sock" "$f2"
    assert_stack "push: stack newest first" "$home" "$f2" "$f1"
    run "$home" "$local_sock" release "$f2"
    assert_link "pop(newest): primary is older session" "$home/.ssh/ssh_auth_sock" "$f1"
    assert_stack "pop(newest): older remains" "$home" "$f1"
    run "$home" "$local_sock" release "$f1"
    assert_link "pop(last): primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_stack "pop(last): stack empty" "$home"
}

# The older session ending first leaves the newest active; the last pop clears the primary without local.
t_pop_older_first() {
    local home f1 f2
    home=$(new_home)
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    start_agent "$f1" >/dev/null
    start_agent "$f2" >/dev/null
    init_run "$home" "" "$f1"
    init_run "$home" "" "$f2"
    run "$home" "" release "$f1"
    assert_link "pop(older): primary stays newest" "$home/.ssh/ssh_auth_sock" "$f2"
    assert_stack "pop(older): newest remains" "$home" "$f2"
    run "$home" "" release "$f2"
    assert_absent "pop(last, no local): primary absent" "$home/.ssh/ssh_auth_sock"
    assert_stack "pop(last, no local): stack empty" "$home"
}

# Logging in again with a known socket moves it to the top without duplicating it.
t_relogin_moves_top() {
    local home f1 f2
    home=$(new_home)
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    start_agent "$f1" >/dev/null
    start_agent "$f2" >/dev/null
    init_run "$home" "" "$f1"
    init_run "$home" "" "$f2"
    init_run "$home" "" "$f1"
    assert_stack "relogin: moved to top, no duplicate" "$home" "$f1" "$f2"
    assert_link "relogin: primary follows" "$home/.ssh/ssh_auth_sock" "$f1"
}

# Every init (both modes) prunes entries whose socket is gone and repoints.
t_prune() {
    local home local_sock f1 f2 f3 p2
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    f3="$home/.ssh/agent/s.h3.sshd.r3"
    start_agent "$f1" >/dev/null
    p2=$(start_agent "$f2")
    start_agent "$f3" >/dev/null
    init_run "$home" "$local_sock" "$f1"
    init_run "$home" "$local_sock" "$f2"
    disconnect "$p2" "$f2"
    init_run "$home" "$local_sock"
    assert_stack "prune: dead newest dropped" "$home" "$f1"
    assert_link "prune: primary is live older" "$home/.ssh/ssh_auth_sock" "$f1"
    init_run_ni "$home" "$local_sock" "$f3"
    assert_stack "prune(non-interactive): no push" "$home" "$f1"
}

# A non-interactive session never pushes; an empty stack still selects local.
t_non_interactive() {
    local home local_sock f1 f2
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    start_agent "$f1" >/dev/null
    start_agent "$f2" >/dev/null
    init_run "$home" "$local_sock" "$f1"
    init_run_ni "$home" "$local_sock" "$f2"
    assert_link "non-interactive: primary keeps interactive session" "$home/.ssh/ssh_auth_sock" "$f1"
    assert_stack "non-interactive: not pushed" "$home" "$f1"

    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$f1" >/dev/null
    init_run_ni "$home" "$local_sock" "$f1"
    assert_link "non-interactive(empty): primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"

    home=$(new_home)
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$f1" >/dev/null
    init_run_ni "$home" "" "$f1"
    assert_absent "non-interactive(no local): primary absent" "$home/.ssh/ssh_auth_sock"
    expect_rc "init: rejects unknown flag" 1 run "$home" "" init --bogus
}

# A nested shell inherits the primary path itself; it never becomes an entry.
t_nested_shell() {
    local home f1
    home=$(new_home)
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$f1" >/dev/null
    init_run "$home" "" "$f1"
    init_run "$home" "" "$home/.ssh/ssh_auth_sock"
    assert_stack "nested: primary path not pushed" "$home" "$f1"
    assert_link "nested: primary unchanged" "$home/.ssh/ssh_auth_sock" "$f1"
}

# Release works after sshd already removed the socket.
t_release_deleted_socket() {
    local home local_sock f1 p1
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    p1=$(start_agent "$f1")
    init_run "$home" "$local_sock" "$f1"
    disconnect "$p1" "$f1"
    expect_rc "release(deleted): exit 0" 0 run "$home" "$local_sock" release "$f1"
    assert_link "release(deleted): primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_stack "release(deleted): stack empty" "$home"
}

# Releasing an unknown socket or the local agent changes nothing.
t_release_noop() {
    local home local_sock f1
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$f1" >/dev/null
    init_run "$home" "$local_sock" "$f1"
    expect_rc "release(unknown): exit 0" 0 run "$home" "$local_sock" release "$home/.ssh/agent/s.hx.sshd.rx"
    expect_rc "release(local): exit 0" 0 run "$home" "$local_sock" release "$local_sock"
    assert_stack "release(noop): stack unchanged" "$home" "$f1"
    assert_link "release(noop): primary unchanged" "$home/.ssh/ssh_auth_sock" "$f1"
    expect_rc "release: rejects relative path" 1 run "$home" "$local_sock" release relative.sock
}

# Release never talks to an agent: a hung local agent is still selected.
t_release_no_agent_protocol() {
    local home local_sock f1 pl
    home=$(new_home)
    local_sock="$home/local.sock"
    pl=$(start_agent "$local_sock")
    kill -KILL "$pl" 2>/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$f1" >/dev/null
    init_run "$home" "$local_sock" "$f1"
    run "$home" "$local_sock" release "$f1"
    assert_link "release(no protocol): primary is hung local" "$home/.ssh/ssh_auth_sock" "$local_sock"
}

# fixup drops a hung newest entry, selects the next responsive one; --local forgets all.
t_fixup() {
    local home local_sock f1 f2 p2
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    start_agent "$f1" >/dev/null
    p2=$(start_agent "$f2")
    init_run "$home" "$local_sock" "$f1"
    init_run "$home" "$local_sock" "$f2"
    kill -KILL "$p2" 2>/dev/null
    sleep 0.2
    expect_rc "fixup: exit 0" 0 run "$home" "$local_sock" fixup
    assert_link "fixup: primary is responsive older" "$home/.ssh/ssh_auth_sock" "$f1"
    assert_stack "fixup: hung entry dropped" "$home" "$f1"
    expect_rc "fixup --local: exit 0" 0 run "$home" "$local_sock" fixup --local
    assert_link "fixup --local: primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    assert_stack "fixup --local: stack cleared" "$home"
    expect_rc "fixup --local: dies without local socket" 1 run "$home" "" fixup --local
}

# Migration seeds live forwarded slot targets (old primary newest) and removes the backup slot.
t_migration() {
    local home local_sock f1 f2
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    start_agent "$f1" >/dev/null
    start_agent "$f2" >/dev/null
    ln -s -- "$f2" "$home/.ssh/ssh_auth_sock"
    ln -s -- "$f1" "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" "$local_sock"
    assert_stack "migration: slots seeded, primary newest" "$home" "$f2" "$f1"
    assert_link "migration: primary kept" "$home/.ssh/ssh_auth_sock" "$f2"
    assert_absent "migration: backup slot removed" "$home/.ssh/ssh_auth_sock_b"

    home=$(new_home)
    ln -s -- "$local_sock" "$home/.ssh/ssh_auth_sock"
    ln -s -- "$home/.ssh/agent/s.hd.sshd.rd" "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" "$local_sock"
    assert_stack "migration(dead backup): nothing seeded" "$home"
    assert_absent "migration(dead backup): backup slot removed" "$home/.ssh/ssh_auth_sock_b"
    assert_link "migration(dead backup): primary local" "$home/.ssh/ssh_auth_sock" "$local_sock"
}

# Legacy /dev/null placeholders are cleared.
t_legacy_placeholders() {
    local home
    home=$(new_home)
    ln -s -- /dev/null "$home/.ssh/ssh_auth_sock"
    ln -s -- /dev/null "$home/.ssh/ssh_auth_sock_b"
    init_run "$home" ""
    assert_absent "legacy: primary cleared" "$home/.ssh/ssh_auth_sock"
    assert_absent "legacy: backup cleared" "$home/.ssh/ssh_auth_sock_b"
}

# A non-symlink primary is refused with a message and left untouched.
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

# A local ssh-agent layout socket (tag "agent") is not forwarded and never pushed.
t_local_agent_layout() {
    local home local_sock local_agent
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    local_agent="$home/.ssh/agent/s.ha.agent.ra"
    start_agent "$local_agent" >/dev/null
    init_run "$home" "$local_sock" "$local_agent"
    assert_stack "local-agent: not pushed" "$home"
    assert_link "local-agent: primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
}

# A herdr stable link is never pushed, whatever it points at.
t_herdr_link() {
    local home local_sock f1 other link
    home=$(new_home)
    local_sock="$home/local.sock"
    start_agent "$local_sock" >/dev/null
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    start_agent "$f1" >/dev/null
    mkdir -p -- "$home/.config/herdr"
    other="$home/.config/herdr/other.sock"
    start_agent "$other" >/dev/null
    link="$home/.config/herdr/herdr.sock.agent"
    ln -s -- "$f1" "$link"
    init_run "$home" "$local_sock" "$link"
    assert_stack "herdr-link: layout target not pushed" "$home"
    assert_link "herdr-link: primary is local" "$home/.ssh/ssh_auth_sock" "$local_sock"
    ln -sfn -- "$other" "$link"
    init_run "$home" "$local_sock" "$link"
    assert_stack "herdr-link: non-layout target not pushed" "$home"
    ln -sfn -- "$home/.ssh/ssh_auth_sock" "$link"
    init_run "$home" "$local_sock" "$link"
    assert_stack "herdr-link: link to primary not pushed" "$home"
    assert_link "herdr-link: primary still local" "$home/.ssh/ssh_auth_sock" "$local_sock"
}

# A herdr link entry is pruned in both modes, so the primary falls back to
# the next raw entry.
t_herdr_link_legacy_entry() {
    local home f1 f2 link
    home=$(new_home)
    f1="$home/.ssh/agent/s.h1.sshd.r1"
    f2="$home/.ssh/agent/s.h2.sshd.r2"
    start_agent "$f1" >/dev/null
    start_agent "$f2" >/dev/null
    init_run "$home" "" "$f1"
    link="$home/.config/herdr/herdr.sock.agent"
    mkdir -p -- "$home/.config/herdr"
    ln -s -- "$f2" "$link"
    ln -s -- "$link" "$home/.ssh/agent-sessions/9999999999999999-1"
    init_run_ni "$home" "" "$f2"
    assert_stack "herdr-legacy: entry pruned" "$home" "$f1"
    assert_link "herdr-legacy: primary is the raw entry" "$home/.ssh/ssh_auth_sock" "$f1"
}

t_bootstrap_local
t_bootstrap_none
t_local_missing_selected
t_push_pop_newest
t_pop_older_first
t_relogin_moves_top
t_prune
t_non_interactive
t_nested_shell
t_release_deleted_socket
t_release_noop
t_release_no_agent_protocol
t_fixup
t_migration
t_legacy_placeholders
t_non_symlink_guard
t_local_agent_layout
t_herdr_link
t_herdr_link_legacy_entry

printf 'ssh-agent-slot.test: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
