{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.29.6/rtx-v1.29.6-linux-x64";
      sha256 = "08ryxxhg3h7c9ddd4b6ysvwnb2hrvi56nmb84hfb8xriacvraxg0";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.29.6/rtx-v1.29.6-macos-arm64";
      sha256 = "0gwrg38mjj8l0qkvaqp2mw3cli0x5y5b3bly0br730dhkbgi58m9";
    };
  };

in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.20.2";

  # Supported platforms are asserted automatically by the meta.platforms field
  src = sources.${system};
  dontUnpack = true;

  # From https://nixos.wiki/wiki/Packaging/Binaries
  # lib.optionals returns [ ] if the condition is false so it's a noop on other platforms
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
