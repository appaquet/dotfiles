{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixantic = {
      url = "github:appaquet/nixantic";
      #url = "path:/home/appaquet/dotfiles/nixantic";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.home-manager.follows = "home-manager";
    };

    secrets = {
      url = "github:appaquet/dotfiles-secrets";
      #url = "path:/home/appaquet/dotfiles/secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotblip = {
      url = "github:appaquet/dotblip";
      # url = "path:/home/appaquet/dotfiles/dotblip";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixos";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixos"; # need to be on same channel
    };

    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        imports = [
          inputs.nixantic.flakeModules.default
          ./overlays
          ./home-manager/modules/agentic/flake-module.nix
          ./home-manager
          ./nixos
          ./darwin
        ];

        perSystem =
          { pkgs, ... }:
          {
            checks.fmt-safety =
              pkgs.runCommand "fmt-safety"
                {
                  nativeBuildInputs = [
                    pkgs.git
                    pkgs.just
                  ];
                }
                ''
                  fixture="$TMPDIR/fixture"
                  mkdir -p "$fixture/bin" "$fixture/harness"

                  # A stub formatter records which files the fmt task selects.
                  cat >"$fixture/bin/nixfmt" <<'EOF'
                  #!${pkgs.runtimeShell}
                  set -eu

                  for file in "$@"; do
                    printf '{ formatted = true; }\n' >"$file"
                  done
                  EOF
                  chmod +x "$fixture/bin/nixfmt"

                  printf '{tracked=1;}\n' >"$fixture/tracked.nix"
                  printf 'harness/\n' >"$fixture/.gitignore"
                  printf '{ignored=1;}\n' >"$fixture/harness/ignored.nix"
                  cp "$fixture/harness/ignored.nix" "$fixture/ignored-before"

                  # The build sandbox has no /usr/bin/env, so point recipe shebangs at the build shell.
                  cp ${./justfile} "$fixture/justfile"
                  sed -i -E "s|^([[:space:]]*)#!/usr/bin/env bash[[:space:]]*$|\1#!${pkgs.runtimeShell}|" "$fixture/justfile"

                  git -C "$fixture" init --quiet
                  git -C "$fixture" add .gitignore tracked.nix

                  PATH="$fixture/bin:$PATH" just \
                    --justfile "$fixture/justfile" \
                    --working-directory "$fixture" \
                    fmt

                  test "$(cat "$fixture/tracked.nix")" = '{ formatted = true; }'
                  cmp "$fixture/ignored-before" "$fixture/harness/ignored.nix"
                  touch "$out"
                '';

            devShells.default = pkgs.mkShell {
              packages = [
                pkgs.bun
                pkgs.just
                pkgs.nixfmt
              ];
            };
          };
      }
    );
}
