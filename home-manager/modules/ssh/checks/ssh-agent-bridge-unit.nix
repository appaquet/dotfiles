{ pkgs, home-manager }:

# Renders the ssh agent fish init from the real home-manager module and runs the
# shell-shape suite against that rendered text, so a branch that drifts from its
# detection fails here. The suite stubs ps to drive each shell shape, and uses
# real ssh-agent instances for the forwarded socket layout.
let
  home = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;

    modules = [
      ../module.nix
      {
        dotfiles.ssh.agent.enable = true;
        programs.fish.enable = true;

        home = {
          username = "tester";
          homeDirectory = "/home/tester";
          stateVersion = "24.11";
        };
      }
    ];
  };

  fishInit = pkgs.writeText "ssh-agent-init.fish" home.config.programs.fish.shellInit;
in
pkgs.runCommand "ssh-agent-bridge-unit-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.fish
      pkgs.gnused
      pkgs.openssh
    ];
  }
  ''
    set -eu

    export FISH_INIT=${fishInit}

    if ! bash ${../tests}/ssh-agent-bridge.test.sh >unit.out 2>&1; then
      cat unit.out >&2
      exit 1
    fi

    if ! grep -E "ssh-agent-bridge.test: [0-9]+ passed, 0 failed" unit.out >/dev/null; then
      echo "The ssh-agent-bridge suite did not fully pass" >&2
      cat unit.out >&2
      exit 1
    fi

    tail -n 1 unit.out
    touch "$out"
  ''
