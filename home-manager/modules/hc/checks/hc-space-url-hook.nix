{ pkgs }:

# Regression tests for the fish hook that labels a Herdr terminal with its workspace URL. A stub
# `hc` records every call, so each case compares the exact label commands the hook sent.
pkgs.runCommand "hc-space-url-hook-check"
  {
    nativeBuildInputs = [ pkgs.fish ];
  }
  ''
    set -eu
    mkdir bin
    cat >bin/hc <<'EOF'
    #!/bin/sh
    echo "$*" >>"$HC_CALLS"
    EOF
    chmod +x bin/hc
    export PATH="$PWD/bin:$PATH"
    export HC_CALLS="$PWD/calls"
    export HOME="$TMPDIR"

    # Runs a fish snippet with the hook watching HIGH then LOW, and compares the recorded calls.
    run_case() {
      name=$1 script=$2 expected=$3
      : >"$HC_CALLS"
      fish --no-config -c "source ${../space-url.fish}; $script"
      if [ "$(cat "$HC_CALLS")" != "$expected" ]; then
        echo "case '$name' failed" >&2
        echo "expected:" >&2
        printf '%s\n' "$expected" >&2
        echo "got:" >&2
        cat "$HC_CALLS" >&2
        exit 1
      fi
    }

    run_case "labels a set var" \
      'set -gx HC_TERMINAL_ID t1; hc_space_url_watch HIGH LOW; set -gx LOW http://low' \
      'label t1 space.url=http://low'

    run_case "higher priority var wins" \
      'set -gx HC_TERMINAL_ID t1; hc_space_url_watch HIGH LOW; set -gx LOW http://low; set -gx HIGH http://high; set -gx LOW http://low2' \
      'label t1 space.url=http://low
    label t1 space.url=http://high'

    run_case "changed value relabels" \
      'set -gx HC_TERMINAL_ID t1; hc_space_url_watch HIGH LOW; set -gx HIGH http://a; set -gx HIGH http://b' \
      'label t1 space.url=http://a
    label t1 space.url=http://b'

    run_case "unsetting all vars clears the label" \
      'set -gx HC_TERMINAL_ID t1; hc_space_url_watch HIGH LOW; set -gx HIGH http://a; set -gx LOW http://b; set -e HIGH; set -e LOW' \
      'label t1 space.url=http://a
    label t1 space.url=http://b
    label t1 space.url='

    run_case "same value is sent once" \
      'set -gx HC_TERMINAL_ID t1; hc_space_url_watch HIGH LOW; set -gx HIGH http://a; set -gx HIGH http://a' \
      'label t1 space.url=http://a'

    run_case "inherited var is labelled at start" \
      'set -gx HC_TERMINAL_ID t1; set -gx LOW http://inherited; hc_space_url_watch HIGH LOW' \
      'label t1 space.url=http://inherited'

    run_case "no var set sends nothing at start" \
      'set -gx HC_TERMINAL_ID t1; hc_space_url_watch HIGH LOW' \
      ""

    run_case "outside Herdr sends nothing" \
      'set -e HC_TERMINAL_ID; hc_space_url_watch HIGH LOW; set -gx HIGH http://a' \
      ""

    touch $out
  ''
