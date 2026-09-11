{
  home-manager,
  lib,
  nono,
  pkgs,
  upstreamPi,
}:

let
  # Loading a real npm-shaped extension exercises Pi's package discovery and
  # protects the Node runtime required by extensions that import node:sqlite.
  extensionFixture = pkgs.runCommand "pi-runtime-extension-fixture" { } ''
    mkdir -p "$out/extensions"
    cat >"$out/package.json" <<'JSON'
    {"name":"pi-runtime-extension-fixture","pi":{"extensions":["./extensions"]}}
    JSON
    cat >"$out/extensions/probe.ts" <<'TS'
    import { DatabaseSync } from "node:sqlite";

    export default function (pi: any) {
      const database = new DatabaseSync(":memory:");
      database.exec("CREATE TABLE smoke (value TEXT)");
      database.close();
      pi.registerCommand("smoke-probe", {
        description: "deterministic runtime smoke probe",
        handler: async () => {},
      });
    }
    TS
  '';

  # The smoke test executes the package selected by the production module, not
  # a separately chosen test package that could drift from production.
  productionHome = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs.inputs'.llm-agents.packages.pi = upstreamPi;
    modules = [
      ../module.nix
      {
        home = {
          username = "pi-runtime";
          homeDirectory = "/home/pi-runtime";
          stateVersion = "24.11";
        };
        dotfiles.pi.enable = true;
      }
    ];
  };
  selectedPi = productionHome.config.dotfiles.pi.package;

  runtimeSmoke = pkgs.runCommand "pi-node-runtime-smoke" { nativeBuildInputs = [ pkgs.jq ]; } ''
    export HOME="$TMPDIR/home"
    export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
    export PI_OFFLINE=1
    mkdir -p "$PI_CODING_AGENT_DIR"
    printf '%s\n' '{"packages":["${extensionFixture}"]}' >"$PI_CODING_AGENT_DIR/settings.json"

    printf '%s\n' '{"id":"probe","type":"get_commands"}' \
      | timeout 30 ${selectedPi}/bin/pi --mode rpc --no-session --no-approve \
      >"$HOME/response.jsonl"
    jq -s -e '
      any(.[].data.commands[]?; .name == "smoke-probe")
    ' "$HOME/response.jsonl"
    touch "$out"
  '';

  # Nono cannot run inside the Nix build sandbox. This generated host smoke
  # validates the real profile, helper commands, wrapper, and secret boundary.
  fakeSecret = pkgs.writeText "pi-nono-smoke-secret" "expected-secret";
  fakePi = pkgs.writeShellScriptBin "pi" ''
    printf 'secret=%s\narg=%s\n' "''${SMOKE_SECRET-}" "$1" >"$HOME/.pi/agent/nono-invocation"
  '';
  smokePkgs = pkgs.extend (_: _: { inherit nono; });
  smokeHome = home-manager.lib.homeManagerConfiguration {
    pkgs = smokePkgs;
    extraSpecialArgs.inputs'.llm-agents.packages.pi = upstreamPi;
    modules = [
      ../../../nono/default.nix
      ../module.nix
      {
        home = {
          username = "pi-smoke";
          homeDirectory = "/home/pi-smoke";
          stateVersion = "24.11";
        };
        dotfiles.pi = {
          enable = true;
          package = fakePi;
          settings.smoke = "generated";
          environment.SMOKE_SECRET.file = toString fakeSecret;
        };
        dotfiles.nono.profiles.pi = {
          meta.version = "1.0.0";
          extends = "coding-agent";
          filesystem = {
            allow = [
              "$HOME/.pi"
              "$HOME/.local/share/pi"
            ];
            read_file = [ (toString fakeSecret) ];
          };
          security.signal_mode = "allow_all";
          network.block = true;
        };
      }
    ];
  };
  packages = smokeHome.config.home.packages;
  nonoPi = lib.findFirst (package: lib.getName package == "nono-pi") null packages;
  maybePackages = builtins.filter (package: lib.hasPrefix "maybe" (lib.getName package)) packages;
  profileSource = name: smokeHome.config.home.file.".config/nono/profiles/${name}.json".source;

  nonoSmoke = pkgs.writeShellApplication {
    name = "pi-nono-smoke";
    runtimeInputs = [
      nono
      pkgs.coreutils
      pkgs.jq
    ]
    ++ maybePackages;
    text = ''
      test "$(uname -s)" = Linux
      # A private worktree prevents repository-local nono hooks from affecting
      # the result and keeps every runtime write under the disposable HOME.
      home="$(mktemp -d /var/tmp/pi-nono-smoke.XXXXXX)"
      trap 'rm -rf "$home"' EXIT HUP INT TERM
      mkdir -p "$home/.config/nono/profiles" "$home/.pi" "$home/.local/share/pi" "$home/work"
      cp ${profileSource "machine"} "$home/.config/nono/profiles/machine.json"
      cp ${profileSource "coding-agent"} "$home/.config/nono/profiles/coding-agent.json"
      cp ${profileSource "pi"} "$home/.config/nono/profiles/pi.json"
      cd "$home/work"

      HOME="$home" ${nonoPi}/bin/nono-pi smoke-argument
      jq -e '.smoke == "generated"' "$home/.pi/agent/settings.json"
      printf '%s\n' 'secret=expected-secret' 'arg=smoke-argument' >"$home/expected"
      diff -u "$home/expected" "$home/.pi/agent/nono-invocation"
    '';
  };
in

assert selectedPi == upstreamPi.override { useBun = false; };
assert nonoPi != null;

{
  inherit nonoSmoke runtimeSmoke;
}
