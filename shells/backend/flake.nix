{
  # To use, create .envrc with:
  # use flake /home/appaquet/dotfiles/shells/backend --impure
  # watch_file /home/appaquet/dotfiles/shells/backend/flake.nix

  description = "HF backend";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
          (pkgs.python312.withPackages (
            p: with p; [
              pandas
              opencv-python
            ]
          )).override
            { ignoreCollisions = true; }
        );

        tfSources = {
          # x86_64-linux = pkgs.fetchurl {
          #   url = "https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-2.7.0.tar.gz";
          #   hash = "sha256-7VOb6Wqcbkze4sBVoe6isr6JUsumG/0Q56g6tl4MfbM=";
          # };
          # aarch64-darwin = pkgs.fetchurl {
          #   url = "https://github.com/zia-ai/tensorflow-go/releases/download/v2.7.0/libtensorflow-macos-2.7.0.tar.gz";
          #   hash = "sha256-7+xE07+EgZeiIiTYknmTMUeHqGv4amo5j9SguVK9o8=";
          # };
          # version = "2.7.0";

          x86_64-linux = pkgs.fetchurl {
            url = "https://storage.googleapis.com/tensorflow/versions/2.18.0/libtensorflow-cpu-linux-x86_64.tar.gz";
            hash = "sha256-YFv8s3DH5+yYHqutqID2B4Tj3gGDlb6VyVw+VZLD2aI=";
          };
          aarch64-darwin = pkgs.fetchurl {
            url = "https://storage.googleapis.com/tensorflow/versions/2.18.0/libtensorflow-cpu-darwin-arm64.tar.gz";
            hash = "sha256-RiJX0nknMNyxMfzyG8gmGSrlosQYU19jR9BR8Q/Ivoo=";
          };
          version = "2.18.0";
        };

        tfSrc = tfSources.${pkgs.stdenv.hostPlatform.system};
        libtensorflow218 = pkgs.stdenv.mkDerivation {
          name = "libtensorflow";
          dontUnpack = true;
          installPhase = ''
            mkdir -p $out
            cd $out
            tar -zxvf ${tfSrc}
          '';

          nativeBuildInputs = pkgs.lib.optional pkgs.stdenv.hostPlatform.isDarwin pkgs.fixDarwinDylibNames;
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            name = "backend";

            buildInputs = (
              with pkgs;
              [
                clang

                (rust-bin.stable.latest.default.override {
                  extensions = [
                    "rust-src"
                    #"rust-analyzer" (overridden below)
                    "llvm-tools-preview"
                  ];
                })
                rust-analyzer # we want the latest goodies

                stdenv.cc.cc.lib
                llvmPackages.libclang
                llvmPackages.libcxxClang
                llvmPackages.bintools-unwrapped # llvm-cov
                lldb
                zlib
                openssl

                #libtensorflow
                libtensorflow218

                # static build of go bins
                # some stuff breaks if we enable all the time
                # glibc
                # glibc.static

                # unstructured.io deps
                libGL
                glib
                tesseract
              ]
            );

            nativeBuildInputs = (
              with pkgs;
              [
                pkg-config # required by go for oxidized

                nodejs
                yarn
                jemalloc # for tooling

                python3
                uv

                # LSPs
                pyright
                ruff
                jsonnet-language-server
              ]
            );

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
