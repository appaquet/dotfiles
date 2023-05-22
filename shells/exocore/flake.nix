{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/exocore --impure
  # watch_file /home/appaquet/dotfiles/shells/exocore/flake.nix

  description = "exomind";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              protobuf
              capnproto
            ];

            nativeBuildInputs = [ ];
          };
        };
      });
}
