{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/exotwo --impure
  # watch_file /home/appaquet/dotfiles/shells/exotwo/flake.nix

  description = "exotwo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            name = "exotwo";

            buildInputs = with pkgs; [
              pyright
            ];

            nativeBuildInputs = with pkgs; [
              (python3.withPackages (
                p: with p; [
                  numpy
                  psycopg
                  pandas
                ]
              ))
              (poetry.override { python3 = python3; })
            ];

            shellHook = ''
              # Postgres drivers need stdc++
              export LD_LIBRARY_PATH="${
                pkgs.lib.makeLibraryPath [
                  pkgs.stdenv.cc.cc
                  pkgs.stdenv.cc.cc.lib
                ]
              }"
            '';

          };
        };
      }
    );
}
