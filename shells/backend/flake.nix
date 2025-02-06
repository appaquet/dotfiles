{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/backend --impure
  # watch_file /home/appaquet/dotfiles/shells/backend/flake.nix

  description = "HF backend";

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

        python3 = (
          (pkgs.python310.withPackages (
            p: with p; [
              #tensorflow
              #grpcio-tools
              #click
              #keras
              #mypy-protobuf
              #numpy
              #spacy
              pandas
              opencv-python
            ]
          )).override
            { ignoreCollisions = true; }
        );
      in
      {
        devShells = {
          default = pkgs.mkShell rec {
            name = "backend";

            buildInputs = with pkgs; [
              clang

              (rust-bin.stable.latest.default.override {
                extensions = [
                  "rust-src"
                  "rust-analyzer"
                ];
              })

              stdenv.cc.cc.lib
              llvmPackages.libclang
              llvmPackages.libcxxClang
              zlib
              openssl
              libtensorflow

              # static build of go bins
              # some stuff breaks if we enable all the time
              #glibc
              #glibc.static

              # unstructured.io deps
              libGL
              glib
              tesseract
            ];

            nativeBuildInputs = with pkgs; [
              pkg-config # required by go for oxidized

              nodejs
              yarn
              jemalloc # for tooling

              python3
              (poetry.override { python3 = python310; })
              pyright
            ];

            # fixes go debugging
            # https://github.com/NixOS/nixpkgs/issues/18995
            hardeningDisable = [ "fortify" ];

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

            shellHook = ''
              # Mostly for python fixes
              # https://nixos.wiki/wiki/Packaging/Quirks_and_Caveats#ImportError:_libstdc.2B.2B.so.6:_cannot_open_shared_object_file:_No_such_file
              # https://discourse.nixos.org/t/poetry-pandas-issue-libz-so-1-not-found/17167/5
              LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
                pkgs.stdenv.cc.cc
                pkgs.zlib
                pkgs.openssl
              ]}"
            '';
          };
        };
      }
    );
}
