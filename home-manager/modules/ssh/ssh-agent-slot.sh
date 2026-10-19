# shellcheck shell=bash
# Shared SSH agent slots: init/probe/release run automatically, fixup repairs explicitly.
# Only fixup and probe touch the agent protocol, always through bounded probes;
# init and release are filesystem-only.
set -euo pipefail

main() {
    local cmd="${1:-}"
    case "$cmd" in
        --help|-h) printf 'Usage: ssh-agent-slot {init [--non-interactive]|probe <slot>|release <socket>|fixup [--local]}\n'; return ;;
        probe)
            # Match exec runs this on every ssh invocation: read-only and
            # lock-free, so it can never block or serialize an ssh call
            (( $# == 2 )) || die "usage: ssh-agent-slot probe <slot>"
            if responsive "$2"; then return 0; fi
            return 1
            ;;
        init)
            (( $# <= 2 )) || die "usage: ssh-agent-slot init [--non-interactive]"
            [[ -z "${2:-}" || "${2:-}" = --non-interactive ]] || die "usage: ssh-agent-slot init [--non-interactive]"
            ;;
        release)
            (( $# == 2 )) && [[ "$2" = /* ]] || die "usage: ssh-agent-slot release <socket>"
            ;;
        fixup)
            (( $# <= 2 )) || die "usage: ssh-agent-slot fixup [--local]"
            [[ -z "${2:-}" || "${2:-}" = --local ]] || die "usage: ssh-agent-slot fixup [--local]"
            ;;
        *) die "usage: ssh-agent-slot {init [--non-interactive]|probe <slot>|release <socket>|fixup [--local]}" ;;
    esac
    [[ ${HOME:-} = /* ]] || die "HOME must be an absolute path"
    local_socket=${local_socket:-}
    dir="$HOME/.ssh"
    primary="$dir/ssh_auth_sock"
    backup="$dir/ssh_auth_sock_b"
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
    primary_target=$(read_slot "$primary")
    backup_target=$(read_slot "$backup")

    if [[ "$cmd" = init ]]; then
        # Register a genuinely incoming forwarded candidate; otherwise
        # bootstrap inactive state. An inherited agent without an
        # SSH_CONNECTION marker never promotes (nested shells), and
        # non-interactive sessions (ssh host cmd) never take over the slots.
        local incoming candidate
        incoming=${SSH_AUTH_SOCK:-}
        if [[ "${2:-}" != --non-interactive && -n ${SSH_CONNECTION:-} && -S "$incoming" ]] &&
            forwarded_socket "$incoming"; then
            if [[ "$incoming" != "$primary_target" ]]; then publish "$incoming"; fi
        elif ! eligible "$primary_target"; then
            candidate=""
            if eligible "$local_socket" && [[ -S "$local_socket" ]]; then candidate=$local_socket; fi
            publish "$candidate"
        fi
        normalize_backup
        return
    fi

    if [[ "$cmd" = release ]]; then
        # A session's forwarded agent leaves the slots when the session ends,
        # whether or not sshd has removed its socket yet. The local agent is
        # never released.
        local gone=$2 next=""
        [[ "$gone" != "$local_socket" ]] || return 0
        if [[ "$primary_target" = "$gone" ]]; then
            if [[ "$backup_target" != "$gone" && -S "$backup_target" ]] && eligible "$backup_target"; then
                next=$backup_target
            elif [[ -S "$local_socket" ]] && eligible "$local_socket"; then
                next=$local_socket
            fi
            write_slot "$primary" "$next"
        elif [[ "$backup_target" = "$gone" ]]; then
            write_slot "$backup" ""
        else
            return 0
        fi
        normalize_backup
        return
    fi

    # fixup: first eligible, responsive candidate wins; a responsive primary
    # stays in place (publish only runs for a non-primary candidate)
    local -a candidates=("$primary_target" "$backup_target" "$local_socket")
    local -A seen=() # de-dup candidates that share a target
    if [[ "${2:-}" = --local ]]; then
        [[ -n "$local_socket" ]] || die "no local agent configured; run fixup without --local"
        candidates=("$local_socket")
    fi
    local candidate
    for candidate in "${candidates[@]}"; do
        eligible "$candidate" || continue
        [[ -z ${seen[$candidate]+yes} ]] || continue
        seen[$candidate]=yes
        responsive "$candidate" || continue
        if [[ "$candidate" != "$primary_target" ]]; then publish "$candidate"; fi
        printf 'ssh-agent-slot: using %s\n' "$candidate"
        return
    done
    die "no responsive eligible agent; reconnect forwarding or unlock 1Password and retry"
}

# A slot's target path; empty when the slot is missing, die when it exists but is not a symlink.
read_slot() {
    local target
    [[ ! -e "$1" || -L "$1" ]] || die "$1 is not a symlink; move it aside first"
    target=$(readlink -- "$1") || return 0
    [[ "$target" = /* ]] || target="$dir/$target"
    printf '%s' "$target"
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

# A forwarded agent socket, or a symlink indirection to one: herdr (>= 0.9.2)
# serves panes a stable agent address it retargets across attaches.
forwarded_socket() {
    local target=$1
    if [[ -L "$target" ]]; then target=$(readlink -- "$target"); fi
    forwarded_shape "$target"
}

# Selectable as a shared agent: absolute, not a legacy /dev/null target, not a slot path
# itself, and either the configured local socket or a forwarded agent (direct
# layout socket or indirection to one).
eligible() {
    [[ "$1" = /* && "$1" != /dev/null && "$1" != "$primary" && "$1" != "$backup" ]] &&
        { [[ -n "$local_socket" && "$1" = "$local_socket" ]] || forwarded_socket "$1"; }
}

# Local agent invariant: hosts that configure one keep it in a slot at all
# times; otherwise a stale ineligible backup is neutralized. Targets are
# re-read since the caller may have rewritten the slots.
normalize_backup() {
    primary_target=$(read_slot "$primary")
    backup_target=$(read_slot "$backup")
    if [[ -n "$local_socket" && "$primary_target" != "$local_socket" ]]; then
        write_slot "$backup" "$local_socket"
    else
        # Never leave both slots on the same target; neutralize stale backups.
        if [[ "$primary_target" = "$backup_target" ]] || ! eligible "$backup_target"; then
            write_slot "$backup" ""
        fi
    fi
}

# Rotate slots: the previous eligible primary becomes backup, $1 becomes primary.
publish() {
    local previous=""
    if eligible "$primary_target"; then previous=$primary_target
    elif eligible "$backup_target"; then previous=$backup_target; fi
    # Never leave both slots on the same target.
    [[ "$previous" != "$1" ]] || previous=""
    write_slot "$backup" "$previous"
    write_slot "$primary" "$1"
}

# Clear inactive slots; atomically repoint populated slots through a temporary symlink.
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
    output=$(SSH_AUTH_SOCK="$1" LC_ALL=C timeout --foreground -s KILL 2s ssh-add -l 2>&1) || status=$?
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
