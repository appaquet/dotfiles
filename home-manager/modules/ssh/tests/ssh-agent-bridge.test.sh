# shellcheck shell=bash
# Suite for the fish shell init that chooses how an ssh agent interacts with the
# shared slot. It runs the rendered init (FISH_INIT) in fish against fake $HOME
# roots and a stub ps that prints the shell's own argv, so each scenario drives
# one shell shape: a herdr-core bridge, a one-off ssh command, a
# shell without ssh, a symlinked incoming agent, and an interactive login.
#
# Real ssh-agent instances bound with -a provide layout-shaped forwarded sockets
# ($fakehome/.ssh/agent/s.<hash>.sshd.<n>); an arbitrary path stands in for the
# configured local agent and a symlink for an agent link inherited from a parent.
set -euo pipefail

init=${FISH_INIT:?usage: FISH_INIT=<rendered fish init> ssh-agent-bridge.test.sh}

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

# Assert two values are identical.
assert_eq() { # assert_eq <label> <expected> <actual>
    if [[ "$2" = "$3" ]]; then
        ok "$1"
    else
        bad "$1 (expected [$2], got [$3])"
    fi
}

# Drop the cursor-shape escapes an interactive fish prints to its output.
strip_ansi() {
    sed $'s/\x1b\\[[0-9;]*[a-zA-Z]//g'
}

# One value from a shell report, last occurrence.
report_value() { # report_value <report> <key>
    sed -n "s/^$2=//p" <<<"$1" | tail -n 1
}

# The argv a herdr-core (hc) machine connection runs on the remote host.
hc_bridge='fish -c sh -c '"'"'p=$(command -v herdr-core) || p=$HOME/.local/bin/herdr-core; [ -x "$p" ] || { echo "herdr-core is not installed here" >&2; exit 127; }; exec "$p" connect'"'"''
one_off='fish -c echo hi'

work=$(mktemp -d "${TMPDIR:-/tmp}/shb.XXXXXX")
tmpdirs+=("$work")
stubs=$work/bin
ps_args=$work/ps.args
report=$work/report.fish
mkdir -p -- "$stubs"
: >"$ps_args"

# The init reads the shell's own command line through ps. The stub's shebang is
# the running bash: the build sandbox has no /usr/bin/env.
cat >"$stubs/ps" <<STUB
#!$(command -v bash)
cat "\${PS_ARGS:?}"
STUB
chmod +x "$stubs/ps"

# The script each scenario runs: the rendered init, then what the shell sees.
cat >"$report" <<REPORT
source $init
printf 'sock=%s\n' "\$SSH_AUTH_SOCK"
if test -L "\$HOME/.ssh/ssh_auth_sock"
    printf 'primary=%s\n' (readlink "\$HOME/.ssh/ssh_auth_sock")
else
    printf 'primary=<missing>\n'
end
set -l count 0
for entry in \$HOME/.ssh/agent-sessions/*
    set count (math \$count + 1)
    printf 'target=%s\n' (readlink "\$entry")
end
printf 'count=%s\n' \$count
REPORT

# New fake home with an empty .ssh/agent dir; prints the home path.
new_home() {
    local home
    home=$(mktemp -d "${TMPDIR:-/tmp}/shb-home.XXXXXX")
    mkdir -p -- "$home/.ssh/agent"
    tmpdirs+=("$home")
    printf '%s' "$home"
}

# Start a live ssh-agent bound to $1; prints the agent pid.
start_agent() {
    local output pid
    output=$(ssh-agent -a "$1" 2>&1) || {
        printf 'ssh-agent-bridge.test: agent start failed: %s\n%s\n' "$1" "$output" >&2
        return 1
    }
    pid=$(awk -F';' '/^SSH_AGENT_PID/ {sub(/SSH_AGENT_PID=/, "", $1); print $1}' <<<"$output")
    [[ -n "$pid" ]] || {
        printf 'ssh-agent-bridge.test: pid parse failed:\n%s\n' "$output" >&2
        return 1
    }
    pids+=("$pid")
    printf '%s' "$pid"
}

# Run one shell shape and print its report. <incoming> is a socket path or -.
run_shell() { # run_shell <home> <argv> <incoming|-> <script|interactive>
    local home=$1 argv=$2 incoming=$3 mode=$4
    local -a command=(env -u SSH_AUTH_SOCK -u SSH_CONNECTION HOME="$home" PS_ARGS="$ps_args" PATH="$stubs:$PATH")
    printf '%s' "$argv" >"$ps_args"
    if [[ "$incoming" != - ]]; then
        command+=(SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" SSH_AUTH_SOCK="$incoming")
    fi
    if [[ "$mode" = interactive ]]; then
        command+=(fish --interactive "$report")
    else
        command+=(fish "$report")
    fi
    "${command[@]}" 2>/dev/null | strip_ansi
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

link_of() {
    readlink -- "$1" 2>/dev/null || printf '<missing>'
}

# A herdr-core bridge registers its forwarded agent like a login does.
home=$(new_home)
sock=$home/.ssh/agent/s.hcbridge.sshd.1
start_agent "$sock" >/dev/null
out=$(run_shell "$home" "$hc_bridge" "$sock" script)
assert_eq "hc bridge: registers one entry" 1 "$(report_value "$out" count)"
assert_eq "hc bridge: entry target" "$sock" "$(report_value "$out" target)"
assert_eq "hc bridge: primary is the entry" "$sock" "$(report_value "$out" primary)"
assert_eq "hc bridge: shell keeps its raw socket" "$sock" "$(report_value "$out" sock)"
assert_eq "hc bridge: released when the shell ends" "" "$(stack_of "$home")"
assert_eq "hc bridge: primary cleared on release" "<missing>" "$(link_of "$home/.ssh/ssh_auth_sock")"

# A one-off non-interactive command registers nothing.
home=$(new_home)
sock=$home/.ssh/agent/s.oneoff.sshd.3
start_agent "$sock" >/dev/null
out=$(run_shell "$home" "$one_off" "$sock" script)
assert_eq "one-off: registers nothing" 0 "$(report_value "$out" count)"
assert_eq "one-off: primary untouched" "<missing>" "$(report_value "$out" primary)"
assert_eq "one-off: shell keeps its raw socket" "$sock" "$(report_value "$out" sock)"

# A shell without ssh registers nothing and exports the slot.
home=$(new_home)
out=$(run_shell "$home" "$hc_bridge" - script)
assert_eq "no ssh: registers nothing" 0 "$(report_value "$out" count)"
assert_eq "no ssh: exports the slot" "$home/.ssh/ssh_auth_sock" "$(report_value "$out" sock)"

# A symlinked incoming agent (a link inherited from a parent shell) is never an entry.
home=$(new_home)
sock=$home/.ssh/agent/s.symlinked.sshd.4
start_agent "$sock" >/dev/null
link=$home/.local/state/agent-link
mkdir -p -- "$(dirname "$link")"
ln -s "$sock" "$link"
out=$(run_shell "$home" "$hc_bridge" "$link" script)
assert_eq "symlinked incoming: registers nothing" 0 "$(report_value "$out" count)"
assert_eq "symlinked incoming: keeps the slot" "$home/.ssh/ssh_auth_sock" "$(report_value "$out" sock)"

# An interactive login still registers its agent and releases it on exit.
home=$(new_home)
sock=$home/.ssh/agent/s.login.sshd.5
start_agent "$sock" >/dev/null
out=$(run_shell "$home" "$one_off" "$sock" interactive)
assert_eq "interactive login: registers one entry" 1 "$(report_value "$out" count)"
assert_eq "interactive login: entry target" "$sock" "$(report_value "$out" target)"
assert_eq "interactive login: keeps the slot" "$home/.ssh/ssh_auth_sock" "$(report_value "$out" sock)"
assert_eq "interactive login: released on exit" "" "$(stack_of "$home")"

printf 'ssh-agent-bridge.test: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
