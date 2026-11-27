{ pkgs }:

# Regression tests for the fish `monitor` function. A Python harness drives a real interactive fish
# in a pseudo-terminal and compares the exact OSC 7501 status frames each case writes.
pkgs.runCommand "fish-monitor-check"
  {
    nativeBuildInputs = [
      pkgs.fish
      pkgs.python3
    ];
  }
  ''
    export HOME="$TMPDIR"
    python3 -I ${./fish_monitor_test.py} ${../monitor.fish}
    touch $out
  ''
