{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/exocore --impure
  # watch_file /home/appaquet/dotfiles/shells/exocore/flake.nix

  description = "exomind";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    #nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs @ { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ (import rust-overlay) ];
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              clang
              protobuf
              capnproto
              nodejs
              yarn
              nix-ld
            ];

            nativeBuildInputs = with pkgs; [
              clang
              llvmPackages.libclang
              llvmPackages.libcxxClang
              zlib
              glib
            ];

            NODE_OPTIONS = "--openssl-legacy-provider"; # nodejs SSL error. see https://github.com/NixOS/nixpkgs/issues/209668

            NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc
              pkgs.clang
              pkgs.llvmPackages.libclang
              pkgs.llvmPackages.libcxxClang
              pkgs.zlib
              pkgs.glib
            ];
            NIX_LD = builtins.readFile "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
          };
        };
      });
}
