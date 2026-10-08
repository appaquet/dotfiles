# shellcheck shell=bash
# Shared SSH agent slots: init/probe run automatically, fixup repairs explicitly.
# Only fixup and probe touch the agent protocol, always through bounded probes;
# init is filesystem-only.
set -euo pipefail

main() {
    local cmd="${1:-}"
    case "$cmd" in
        --help|-h) printf 'Usage: ssh-agent-slot {init|probe <slot>|fixup [--local]}\n'; return ;;
        probe)
            # Match exec runs this on every ssh invocation: read-only and
            # lock-free, so it can never block or serialize an ssh call
            (( $# == 2 )) || die "usage: ssh-agent-slot probe <slot>"
            if responsive "$2"; then return 0; fi
            return 1
            ;;
        init)
            (( $# == 1 )) || die "usage: ssh-agent-slot init"
            ;;
        fixup)
            (( $# <= 2 )) || die "usage: ssh-agent-slot fixup [--local]"
            [[ -z "${2:-}" || "${2:-}" = --local ]] || die "usage: ssh-agent-slot fixup [--local]"
            ;;
        *) die "usage: ssh-agent-slot {init|probe <slot>|fixup [--local]}" ;;
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
        # bootstrap placeholder state. An inherited agent without an
        # SSH_CONNECTION marker never promotes (nested shells).
        local incoming candidate
        incoming=${SSH_AUTH_SOCK:-}
        if [[ -n ${SSH_CONNECTION:-} && -S "$incoming" ]] && forwarded "$incoming"; then
            if [[ "$incoming" != "$primary_target" ]]; then publish "$incoming"; fi
        elif ! eligible "$primary_target"; then
            candidate=/dev/null
            if eligible "$local_socket" && [[ -S "$local_socket" ]]; then candidate=$local_socket; fi
            publish "$candidate"
        fi
        # Local agent invariant: hosts that configure one keep it in a slot at all
        # times; otherwise a stale ineligible backup is neutralized. Targets are
        # re-read since a promotion may have rewritten the slots.
        primary_target=$(read_slot "$primary")
        backup_target=$(read_slot "$backup")
        if [[ -n "$local_socket" && "$primary_target" != "$local_socket" ]]; then
            write_slot "$backup" "$local_socket"
        else
            # Never leave both slots on the same target; neutralize stale backups.
            if [[ "$primary_target" = "$backup_target" ]] || ! eligible "$backup_target"; then
                write_slot "$backup" /dev/null
            fi
        fi
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
# sockets) is not forwarded.
forwarded() {
    [[ ! -L "$1" && ( "$1" =~ ^/(private/)?tmp/ssh-[^/]+/agent\.[0-9]+$ ||
        "$1" =~ ^"$HOME"/\.ssh/agent/s\.[^./]+\.sshd\.[^./]+$ ) ]]
}

# Selectable as a shared agent: absolute, not the /dev/null placeholder, not a slot path
# itself, and either the configured local socket or a forwarded layout.
eligible() {
    [[ "$1" = /* && "$1" != /dev/null && "$1" != "$primary" && "$1" != "$backup" ]] &&
        { [[ -n "$local_socket" && "$1" = "$local_socket" ]] || forwarded "$1"; }
}

# Rotate slots: the previous eligible primary becomes backup, $1 becomes primary.
publish() {
    local previous=/dev/null
    if eligible "$primary_target"; then previous=$primary_target
    elif eligible "$backup_target"; then previous=$backup_target; fi
    # Never leave both slots on the same target.
    [[ "$previous" != "$1" ]] || previous=/dev/null
    write_slot "$backup" "$previous"
    write_slot "$primary" "$1"
}

# Atomically repoint a slot symlink at $2: build the link in a temp dir, then mv -T over
# the slot so readers never observe a missing or half-set slot.
write_slot() {
    [[ ! -e "$1" || -L "$1" ]] || die "$1 is not a symlink; move it aside first"
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
