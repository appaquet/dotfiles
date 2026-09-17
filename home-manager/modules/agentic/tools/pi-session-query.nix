{ pkgs }:

pkgs.writeShellApplication {
  name = "pi-session-query";

  runtimeInputs = [
    pkgs.python3
  ];

  text = ''
    exec python3 ${./pi-session-query.py} "$@"
  '';
}
