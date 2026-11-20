{ pkgs }:

# Runs pbcopy and pbpaste with `uname` and SSH_CONNECTION faked, so both OS branches run on any build system.
pkgs.runCommand "utils-pbcopy-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
    ];
  }
  ''
    set -eu

    pbcopy=${../bin/pbcopy}
    pbpaste=${../bin/pbpaste}

    # Fake `uname` and macOS tools on PATH. The system pbcopy is a marker that proves which branch ran.
    mkdir -p shim-linux shim-darwin
    printf '#!/bin/sh\necho Linux\n' > shim-linux/uname
    printf '#!/bin/sh\necho Darwin\n' > shim-darwin/uname
    printf '#!/bin/sh\necho system-pbcopy-ran >&2\n' > system-pbcopy
    chmod +x shim-linux/uname shim-darwin/uname system-pbcopy

    fail() {
      echo "$*" >&2
      exit 1
    }

    # run <shim> <script> [args...]: runs a script with that shim first on PATH
    run() {
      shim="$1"
      shift
      PATH="$PWD/$shim:$PATH" "${pkgs.bash}/bin/bash" "$@"
    }

    # OSC 52 sequence for "héllo\n" (UTF-8 and trailing newline preserved)
    printf '\033]52;c;aMOpbGxvCg==\a' > expected

    # Linux: stdin pipe
    printf 'héllo\n' | PBCOPY_TTY=out.pipe run shim-linux $pbcopy > stdout.pipe
    cmp expected out.pipe || fail "pipe input produced the wrong sequence"
    test ! -s stdout.pipe || fail "pbcopy wrote to stdout"

    # Linux: stdin redirect
    printf 'héllo\n' > in.txt
    PBCOPY_TTY=out.redirect run shim-linux $pbcopy < in.txt
    cmp expected out.redirect || fail "redirected input produced the wrong sequence"

    # SSH session on macOS also uses OSC 52, even with DISPLAY set
    printf 'héllo\n' | SSH_CONNECTION="1 2 3 4" DISPLAY=:0 PBCOPY_TTY=out.ssh run shim-darwin $pbcopy
    cmp expected out.ssh || fail "macOS SSH session did not use OSC 52"

    # No terminal: non-zero with an actionable message
    if printf 'x' | PBCOPY_TTY=/nonexistent/tty run shim-linux $pbcopy 2> err.notty; then
      fail "pbcopy succeeded without a terminal"
    fi
    test "$(wc -l < err.notty)" = 1 && grep -qF "no terminal to write to (/nonexistent/tty)" err.notty || fail "no-terminal message missing: $(cat err.notty)"

    # Over the limit: refuses and says why
    head -c 800000 /dev/zero | tr '\0' a > big.txt
    if PBCOPY_TTY=out.big run shim-linux $pbcopy < big.txt 2> err.big; then
      fail "pbcopy accepted an oversized input"
    fi
    grep -qF "limit 1048576" err.big || fail "size message missing: $(cat err.big)"
    test ! -e out.big || fail "oversized input still reached the terminal"

    # Local macOS session uses the system tool, not OSC 52
    sed "s|/usr/bin/pbcopy|$PWD/system-pbcopy|" $pbcopy > pbcopy-mac
    printf 'x' | PBCOPY_TTY=out.mac run shim-darwin pbcopy-mac 2> err.mac
    grep -qF system-pbcopy-ran err.mac || fail "local macOS did not use the system pbcopy"
    test ! -e out.mac || fail "local macOS wrote OSC 52"

    # Linux pbpaste points at the terminal paste
    if run shim-linux $pbpaste 2> err.paste; then
      fail "Linux pbpaste succeeded"
    fi
    grep -qF "Cmd-V" err.paste || fail "pbpaste message missing: $(cat err.paste)"

    # No leftover clipboard tools or ssh hops
    if grep -E 'xclip|xsel|ssh -|\$DISPLAY' $pbcopy $pbpaste; then
      fail "pbcopy/pbpaste still reference xclip, ssh or DISPLAY"
    fi

    touch $out
  ''
