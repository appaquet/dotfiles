{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/backend --impure
  # watch_file /home/appaquet/dotfiles/shells/backend/flake.nix

  description = "HF backend";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
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

        pkgsUnstable = import nixpkgs-unstable {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ (import rust-overlay) ];
        };

        python3 = (
          (pkgs.python310.withPackages (
            p: with p; [
              pandas
              opencv-python
            ]
          )).override
            { ignoreCollisions = true; }
        );
      in
      {
        devShells = {
          default = pkgs.mkShell {
            name = "backend";

            buildInputs = with pkgs; [
              clang

              (rust-bin.stable.latest.default.override {
                extensions = [
                  "rust-src"
                  #"rust-analyzer" (overridden below)
                  "llvm-tools-preview"
                ];
              })
              pkgsUnstable.rust-analyzer # we want the latest goodies

              stdenv.cc.cc.lib
              llvmPackages.libclang
              llvmPackages.libcxxClang
              llvmPackages.bintools-unwrapped # llvm-cov
              lldb
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

              # LSPs
              pyright
              ruff
              jsonnet-language-server
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
              # For python. Re-exposed to `LD_LIBRARY_PATH` inside python dirs via .envrc's
              # https://nixos.wiki/wiki/Packaging/Quirks_and_Caveats#ImportError:_libstdc.2B.2B.so.6:_cannot_open_shared_object_file:_No_such_file
              # https://discourse.nixos.org/t/poetry-pandas-issue-libz-so-1-not-found/17167/5
              export PYTHON_LD_LIBRARY_PATH="${
                pkgs.lib.makeLibraryPath (
                  with pkgs;
                  [
                    stdenv.cc.cc
                    zlib
                    openssl

                    # For unstructured.io
                    libGL
                    glib
                    tesseract
                  ]
                )
              }"
            '';
          };
        };
      }
    );
}
