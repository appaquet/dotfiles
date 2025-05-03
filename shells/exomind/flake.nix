{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/exomind --impure
  # watch_file /home/appaquet/dotfiles/shells/exomind/flake.nix

  description = "exomind";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      rust-overlay,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
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

              (rust-bin.stable.latest.default.override {
                extensions = [ "rust-src" ];
                targets = [ "wasm32-unknown-unknown" ];
              })
              rust-analyzer

              llvmPackages.libclang
              llvmPackages.libcxxClang
              zlib
              openssl
            ];

            nativeBuildInputs = with pkgs; [
              pkg-config
              python3
              protobuf
              capnproto
              nodejs
              yarn
              openssl
            ];

            NIX_LD_LIBRARY_PATH =
              with pkgs;
              lib.makeLibraryPath [
                stdenv.cc.cc
                clang
                llvmPackages.libclang
                llvmPackages.libcxxClang
                zlib
                openssl
              ];
            NIX_LD = builtins.readFile "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
          };
        };
      }
    );
}
