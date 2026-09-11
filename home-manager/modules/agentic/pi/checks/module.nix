{
  home-manager,
  lib,
  pkgs,
  upstreamPi,
}:

let
  # Keep this check at the public wrapper boundary: one complete successful
  # launch and one rejected state cover the behavior callers depend on.
  fakePi = pkgs.writeShellScriptBin "pi" ''
    {
      printf 'secret=%s\n' "''${PI_TEST_SECRET-}"
      printf 'argc=%s\n' "$#"
      printf 'arg=%s\n' "$@"
    } >>"$HOME/pi-invocations"
    exit "''${PI_TEST_EXIT:-0}"
  '';
  fakeSecret = pkgs.writeText "pi-test-secret" "secret value";

  mkHome =
    modules:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.inputs'.llm-agents.packages.pi = upstreamPi;
      modules = [
        ../module.nix
        {
          home = {
            username = "pi-test";
            homeDirectory = "/home/pi-test";
            stateVersion = "24.11";
          };
        }
      ]
      ++ modules;
    };

  # These evaluations guard enablement and the production Node package choice
  # without duplicating the module's option implementation.
  disabled = mkHome [ ];
  defaultEnabled = mkHome [ { dotfiles.pi.enable = true; } ];
  enabled = mkHome [
    {
      dotfiles.pi = {
        enable = true;
        package = fakePi;
        settings = {
          owner = {
            conflict = "nix";
            configured = true;
          };
          packages = [ "nix-package" ];
        };
        environment.PI_TEST_SECRET.file = toString fakeSecret;
      };
    }
  ];

  managedPackages = builtins.filter (
    package:
    let
      name = lib.getName package;
    in
    name == "pi" || name == "nono-pi"
  ) enabled.config.home.packages;
  piWrapper = lib.findFirst (package: lib.getName package == "pi") null managedPackages;
in

assert builtins.filter (package: lib.getName package == "pi") disabled.config.home.packages == [ ];
assert defaultEnabled.config.dotfiles.pi.package == upstreamPi.override { useBun = false; };
assert piWrapper != null;

pkgs.runCommand "pi-module-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
  }
  ''
    wrapper=${piWrapper}/bin/pi
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.pi/agent"

    # Runtime-only values survive while Nix owns conflicting leaves and arrays.
    cat >"$HOME/.pi/agent/settings.json" <<'JSON'
    {"owner":{"conflict":"runtime","preserved":true},"packages":["runtime-package"],"runtimeOnly":true}
    JSON

    set +e
    PI_TEST_EXIT=23 "$wrapper" --flag -- install
    status=$?
    set -e
    test "$status" = 23
    test "$(stat -c %a "$HOME/.pi/agent/settings.json")" = 600
    jq -e '
      . == {
        "owner": {
          "conflict": "nix",
          "configured": true,
          "preserved": true
        },
        "packages": ["nix-package"],
        "runtimeOnly": true
      }
    ' "$HOME/.pi/agent/settings.json"
    cat >"$TMPDIR/expected-invocation" <<'EOF'
    secret=secret value
    argc=3
    arg=--flag
    arg=--
    arg=install
    EOF
    diff -u "$TMPDIR/expected-invocation" "$HOME/pi-invocations"

    # Invalid state must remain recoverable and must not start upstream Pi.
    rm "$HOME/pi-invocations"
    printf '%s\n' '{"first":true}' '{"second":true}' >"$HOME/.pi/agent/settings.json"
    cp "$HOME/.pi/agent/settings.json" "$TMPDIR/settings-before"
    if "$wrapper" >"$TMPDIR/invalid-out" 2>"$TMPDIR/invalid-err"; then
      echo 'wrapper accepted multiple JSON settings documents' >&2
      exit 1
    fi
    cmp "$TMPDIR/settings-before" "$HOME/.pi/agent/settings.json"
    test ! -e "$HOME/pi-invocations"

    touch "$out"
  ''
