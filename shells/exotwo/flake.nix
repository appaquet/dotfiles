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
          config = {
            allowUnfree = true;
          };
          overlays = [ ];
        };

        python3_override = (
          (pkgs.python313.withPackages (
            p: with p; [
              numpy
              psycopg
              pandas
            ]
          )).override
            {
              ignoreCollisions = true;
            }
        );
      in
      {
        devShells = {
          default = pkgs.mkShell {
            name = "exotwo";

            buildInputs = with pkgs; [
              pyright
              stdenv.cc.cc.lib
              stdenv.cc.cc
            ];

            nativeBuildInputs = with pkgs; [
              python3_override
              (poetry.override { python3 = python313; })
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
