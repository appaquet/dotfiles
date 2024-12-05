{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/exotwo --impure
  # watch_file /home/appaquet/dotfiles/shells/exotwo/flake.nix

  description = "exotwo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ ];
        };

        python3 = ((pkgs.python311.withPackages (p: with p; [
          #tensorflow 
          #grpcio-tools 
          #click
          #keras
          #mypy-protobuf
        ])).override ({ ignoreCollisions = true; }));
      in
      {
        devShells = {
          default = pkgs.mkShell rec {
            name = "exotwo";

            buildInputs = with pkgs; [
            ];

            nativeBuildInputs = with pkgs; [
              python3
              (poetry.override { python3 = python311; })
            ];
          };
        };
      });
}
