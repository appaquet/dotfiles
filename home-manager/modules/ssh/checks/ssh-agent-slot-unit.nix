{ pkgs }:

# Unit tests for the ssh-agent-slot helper. The suite drives the script
# directly against fake $HOME roots with real ssh-agent instances, so it
# needs no wrapper or live agent state. Files are referenced through the
# flake source tree, which only carries git-tracked files.
pkgs.runCommand "ssh-agent-slot-unit-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.openssh
    ];
  }
  ''
    set -eu

    if ! bash ${../tests}/ssh-agent-slot.test.sh ${../ssh-agent-slot.sh} >unit.out 2>&1; then
      cat unit.out >&2
      exit 1
    fi

    if ! grep -E "ssh-agent-slot.test: [0-9]+ passed, 0 failed" unit.out >/dev/null; then
      echo "The ssh-agent-slot suite did not fully pass" >&2
      cat unit.out >&2
      exit 1
    fi

    touch "$out"
  ''
