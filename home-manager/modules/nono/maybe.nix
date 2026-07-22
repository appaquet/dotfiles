{ pkgs, lib, ... }:

let
  maybe-pre = pkgs.writeShellScriptBin "maybe-pre" ''
    if [ -f ".nono/pre.sh" ]; then
      . ".nono/pre.sh"
    fi
  '';

  maybe-in = pkgs.writeShellScriptBin "maybe-in" ''
    if [ -f ".nono/in.sh" ]; then
      . ".nono/in.sh"
    fi

    exec "$@"
  '';

  maybe-profile = pkgs.writeShellScriptBin "maybe-profile" ''
    DEFAULT="$1"
    if [ -f ".nono/profile.json" ]; then
      echo "$(pwd)/.nono/profile.json"
    else
      printf '%s' "$DEFAULT"
    fi
  '';

  maybe-portal = pkgs.writers.writePython3Bin "maybe-portal" {
    flakeIgnore = [
      "E501" # long lines
      "W503" # line break before binary operator
    ];
  } (builtins.readFile ./maybe-portal.py);

  maybe = pkgs.writeShellScriptBin "maybe" (builtins.readFile ./maybe.sh);
in
{
  home.packages = [
    maybe-pre
    maybe-in
    maybe-profile
    maybe-portal
    maybe
  ];
}
