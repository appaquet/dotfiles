{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/exomind --impure
  # watch_file /home/appaquet/dotfiles/shells/exomind/flake.nix

  description = "exomind";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, rust-overlay, flake-utils, ... }:
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
          name = "exomind";

          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              clang
              nix-ld

              (rust-bin.stable.latest.default.override {
                extensions = [ "rust-src" ];
                targets = [ "wasm32-unknown-unknown" ];
              })

              llvmPackages.libclang
              llvmPackages.libcxxClang
              zlib
            ];

            packages = with pkgs; [
              pkg-config
              python3
              protobuf
              capnproto
              nodejs
              yarn
            ];

            NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc
              pkgs.clang
              pkgs.llvmPackages.libclang
              pkgs.llvmPackages.libcxxClang
              pkgs.zlib
            ];
            NIX_LD = builtins.readFile "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
          };
        };
      });
}
