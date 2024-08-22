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
      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
            ];

            packages = with pkgs; [
              protobuf
              nodejs_20
              yarn
            ];
          };
        };
      });
}
