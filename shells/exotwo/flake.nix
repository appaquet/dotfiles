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
              uv
              (pkgs.poetry.withPlugins (
                ps: with ps; [
                  poetry-plugin-shell
                ]
              ))
            ];
          };
        };
      }
    );
}
