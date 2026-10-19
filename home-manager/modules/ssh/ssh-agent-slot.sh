# shellcheck shell=bash
# Shared SSH agent session stack: interactive forwarded logins push their agent
# into $HOME/.ssh/agent-sessions, their shell exit releases it, and the primary
# socket $HOME/.ssh/ssh_auth_sock follows the newest live entry, else the local
# agent. Only fixup touches the agent protocol, always through bounded probes;
# init and release are filesystem-only.
set -euo pipefail

# Entry names sort by login time only under byte-order collation.
export LC_ALL=C

usage_text='ssh-agent-slot {init [--non-interactive]|release <socket>|fixup [--local]}'

main() {
    local cmd="${1:-}"
    case "$cmd" in
        --help|-h) printf 'Usage: %s\n' "$usage_text"; return ;;
        init)
            (( $# <= 2 )) && [[ -z "${2:-}" || "$2" = --non-interactive ]] ||
                die "usage: ssh-agent-slot init [--non-interactive]"
            ;;
        release)
            (( $# == 2 )) && [[ "$2" = /* ]] || die "usage: ssh-agent-slot release <socket>"
            ;;
        fixup)
            (( $# <= 2 )) && [[ -z "${2:-}" || "$2" = --local ]] ||
                die "usage: ssh-agent-slot fixup [--local]"
            ;;
        *) die "usage: $usage_text" ;;
    esac
    [[ ${HOME:-} = /* ]] || die "HOME must be an absolute path"
    local_socket=${local_socket:-}
    dir="$HOME/.ssh"
    primary="$dir/ssh_auth_sock"
    sessions="$dir/agent-sessions"
    lock="$dir/ssh_auth_sock.lock.d"
    local deadline
    temporary=
    [[ -d "$dir" ]] || mkdir -m 700 -- "$dir"
    # Atomic mkdir lock: the dir exists for exactly one holder; bound the wait
    deadline=$((SECONDS + 2))
    until mkdir -m 700 -- "$lock" 2>/dev/null; do
        (( SECONDS < deadline )) || die "slots busy; retry, or remove a stale lock at $lock"
        sleep 0.05
    done
    trap cleanup EXIT
    trap 'exit 1' HUP INT TERM
    [[ ! -e "$primary" || -L "$primary" ]] || die "$primary is not a symlink; move it aside first"
    migrate

    case "$cmd" in
        init) init_sessions "${2:-}" ;;
        release)
            # A session's agent leaves the stack when the session ends, whether
            # or not sshd has removed its socket yet.
            remove_entries "$2" || return 0
            repoint
            ;;
        fixup) fixup_sessions "${2:-}" ;;
    esac
}

# Register a genuinely incoming forwarded agent, then drop dead entries and
# repoint. An inherited agent without an SSH_CONNECTION marker never pushes
# (nested shells), and non-interactive sessions (ssh host cmd) never push.
init_sessions() {
    local incoming=${SSH_AUTH_SOCK:-}
    if [[ "$1" != --non-interactive && -n ${SSH_CONNECTION:-} && -S "$incoming" ]] &&
        incoming_candidate "$incoming"; then
        push "$incoming"
    fi
    prune
    repoint
}

# First responsive entry, newest first, wins; unresponsive entries it passes are
# dropped so the choice sticks. --local forgets every forwarded agent.
fixup_sessions() {
    local entry
    if [[ "$1" = --local ]]; then
        [[ -n "$local_socket" ]] || die "no local agent configured; run fixup without --local"
        while IFS= read -r entry; do rm -f -- "$entry"; done < <(entries)
    else
        prune
        while IFS= read -r entry; do
            if responsive "$entry"; then break; fi
            rm -f -- "$entry"
        done < <(entries)
    fi
    repoint
    if [[ -L "$primary" ]] && responsive "$primary"; then
        printf 'ssh-agent-slot: using %s\n' "$(readlink -- "$primary")"
        return
    fi
    die "no responsive agent; reconnect forwarding or unlock 1Password and retry"
}

# One-time move from the two-slot layout: live forwarded slot targets become
# entries (backup first, so the old primary ends up newest). The legacy backup
# slot is always removed.
migrate() {
    local backup="$dir/ssh_auth_sock_b" slot target
    if [[ ! -d "$sessions" ]]; then
        mkdir -m 700 -- "$sessions"
        for slot in "$backup" "$primary"; do
            [[ -L "$slot" ]] || continue
            target=$(readlink -- "$slot")
            if [[ -S "$target" ]] && incoming_candidate "$target"; then push "$target"; fi
        done
    fi
    if [[ -L "$backup" ]]; then rm -f -- "$backup"; fi
}

# Push $1 as the newest entry; an existing entry for it moves to the top.
push() {
    remove_entries "$1" || true
    ln -s -- "$1" "$sessions/${EPOCHREALTIME/./}-$$"
}

# Remove every entry pointing at $1; fails when none did.
remove_entries() {
    local entry removed=1
    while IFS= read -r entry; do
        if [[ "$(readlink -- "$entry")" = "$1" ]]; then
            rm -f -- "$entry"
            removed=0
        fi
    done < <(entries)
    return "$removed"
}

# Drop entries whose agent socket is gone (a herdr link pointing at its
# unavailable marker counts as gone).
prune() {
    local entry
    while IFS= read -r entry; do
        if [[ ! -S "$entry" ]] || ! incoming_candidate "$(readlink -- "$entry")"; then
            rm -f -- "$entry"
        fi
    done < <(entries)
}

# Point the primary at the newest entry with a live socket, else the configured
# local agent (even if not running yet), else remove it.
repoint() {
    local entry target=""
    while IFS= read -r entry; do
        if [[ -S "$entry" ]]; then
            target=$(readlink -- "$entry")
            break
        fi
    done < <(entries)
    if [[ -z "$target" ]]; then target=$local_socket; fi
    write_slot "$primary" "$target"
}

# Entry symlinks, newest first.
entries() {
    local -a names=()
    local i
    shopt -s nullglob
    names=("$sessions"/*)
    shopt -u nullglob
    for (( i = ${#names[@]} - 1; i >= 0; i-- )); do
        if [[ -L "${names[i]}" ]]; then printf '%s\n' "${names[i]}"; fi
    done
}

# A socket that may become an entry: a forwarded agent that is neither the
# configured local agent nor one of our own paths.
incoming_candidate() {
    [[ "$1" = /* && "$1" != "$primary" && "$1" != "$sessions"/* &&
        ( -z "$local_socket" || "$1" != "$local_socket" ) ]] && forwarded_socket "$1"
}

# A forwarded agent socket, or a symlink indirection to one: herdr (>= 0.9.2)
# serves panes a stable agent address it retargets across attaches.
forwarded_socket() {
    local target=$1
    if [[ -L "$target" ]]; then target=$(readlink -- "$target"); fi
    forwarded_shape "$target"
}

# A recognized OpenSSH forwarded-socket layout: modern sshd-forwarded
# $HOME/.ssh/agent/s.<hash>.sshd.<rand> (sshd tags the socket "sshd"; a local
# ssh-agent's default layout is tagged "agent" and is not forwarded)
# or legacy /tmp/ssh-*/agent.<pid>. Anything else (macOS built-in launchd agent, arbitrary
# sockets) is not a forwarded layout.
forwarded_shape() {
    [[ "$1" =~ ^/(private/)?tmp/ssh-[^/]+/agent\.[0-9]+$ ||
        "$1" =~ ^"$HOME"/\.ssh/agent/s\.[^./]+\.sshd\.[^./]+$ ]]
}

# Remove the slot when $2 is empty; otherwise atomically repoint it through a temporary symlink.
write_slot() {
    [[ ! -e "$1" || -L "$1" ]] || die "$1 is not a symlink; move it aside first"
    if [[ -z "$2" ]]; then
        if [[ -L "$1" ]]; then rm -f -- "$1"; fi
        return 0
    fi
    if [[ -L "$1" && "$(readlink -- "$1")" = "$2" ]]; then return; fi
    temporary=$(mktemp -d "$dir/.ssh-auth.XXXXXX")
    ln -s -- "$2" "$temporary/link"
    mv -Tf -- "$temporary/link" "$1"
    rmdir -- "$temporary"
    temporary=
}

# Bounded liveness probe: ssh-add must answer within 2s. Exit 0 (keys listed) or exit 1
# with "no identities" (live but empty) counts as responsive.
responsive() {
    local output status=0
    [[ -S "$1" ]] || return 1
    output=$(SSH_AUTH_SOCK="$1" timeout --foreground -s KILL 2s ssh-add -l 2>&1) || status=$?
    [[ $status = 0 || ( $status = 1 && "$output" = *"no identities"* ) ]]
}

# Release the lock and remove a half-finished swap dir left by a failed write.
cleanup() {
    if [[ -n "$temporary" ]]; then
        rm -f -- "$temporary/link"
        rmdir -- "$temporary"
    fi
    rmdir -- "$lock"
}

die() { printf 'ssh-agent-slot: %s\n' "$*" >&2; exit 1; }

main "$@"
