{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/playbooks --impure
  # watch_file /home/appaquet/dotfiles/shells/playbooks/flake.nix

  description = "playbooks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
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
          overlays = [];
        };

        python3 = ((pkgs.python311.withPackages(p: with p; [ 
          tensorflow 
          grpcio-tools 
          click
          keras
          mypy-protobuf
        ])).override ({ ignoreCollisions = true; }));
      in
      {
        devShells = {
          default = pkgs.mkShell rec {
            buildInputs = with pkgs; [
              protobuf
              nodejs_20
              yarn
            ];

            packages = [
              python3
              (pkgs.poetry.override { python3 = pkgs.python311; })
            ];

            NODE_OPTIONS = "--openssl-legacy-provider"; # nodejs SSL error. see https://github.com/NixOS/nixpkgs/issues/209668
          };
        };
      });
}
