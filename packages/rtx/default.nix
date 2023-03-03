{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.20.2/rtx-v1.20.2-linux-x64";
      sha256 = "18nwcswph5rhwm71dglc8kfc2b7w1qljmc7z86s6m7xzdf7911rr";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.20.2/rtx-v1.20.2-macos-arm64";
      sha256 = "0lrxy5d6q3bx0qhaijd41vc44i915wbkyhdb5w1msikyd9rd2nj8";
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