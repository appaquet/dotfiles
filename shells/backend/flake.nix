{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/backend --impure
  # watch_file /home/appaquet/dotfiles/shells/backend/flake.nix

  description = "backend";

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

        python3 = ((pkgs.python310.withPackages (p: with p; [
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
              libtensorflow
            ];

            # fixes go debugging
            # https://github.com/NixOS/nixpkgs/issues/18995
            hardeningDisable = [ "fortify" ];

            packages = with pkgs; [
              pkg-config
              python3
              protobuf
              nodejs
              yarn

              (poetry.override { python3 = python310; })
            ];

            NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc
              pkgs.clang
              pkgs.llvmPackages.libclang
              pkgs.llvmPackages.libcxxClang
              pkgs.zlib
            ];
            NIX_LD = builtins.readFile "${pkgs.stdenv.cc}/nix-support/dynamic-linker";

            shellHook = ''
              # fixes libstdc++ issues with python
              # see https://nixos.wiki/wiki/Packaging/Quirks_and_Caveats#ImportError:_libstdc.2B.2B.so.6:_cannot_open_shared_object_file:_No_such_file
              LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib/
            '';
          };
        };
      });
}
