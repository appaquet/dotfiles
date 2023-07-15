{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.34.0/rtx-v1.34.0-linux-x64";
      sha256 = "0z6mynb3rxpr93mhzn6j2sqg7201ggr83va4ixbk3s4r4dz3v80y";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.34.0/rtx-v1.34.0-macos-arm64";
      sha256 = "1bbkhjygmid1j3vw4d4dx30kgc2zdvjbgy51ds50dvfdiy10v86i";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.34.0/rtx-v1.34.0-macos-x64";
      sha256 = "1r4kkglyhxv42qd8njhcw2dzqvindadpypbh99a26vgd076dzpfk";
    };
  };

in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.32.2";

  # Supported platforms are asserted automatically by the meta.platforms field
  src = sources.${system};
  dontUnpack = true;

  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  nativeBuildInputs = lib.optionals stdenv.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/rtx
    chmod +x $out/bin/rtx
  '';

  meta = with lib; {
    description = "Runtime Executor (asdf rust clone) ";
    homepage = "https://github.com/jdxcode/rtx";
    license = licenses.mit;
    platforms = builtins.attrNames sources;
  };
}
