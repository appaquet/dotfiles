{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.34.2/rtx-v1.34.2-linux-x64";
      sha256 = "1c9fh1h7lg1zhyj4x37walh4hpcjp98pfhp0akyvkwqypgpk3pwp";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.34.2/rtx-v1.34.2-macos-arm64";
      sha256 = "1rz7vdpj5zlhhz80qiz76p07s27ywl12hi5i5cnxc9k6xm8k8ilj";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.34.2/rtx-v1.34.2-macos-x64";
      sha256 = "0z6hf36rr65ffr4dnyyw5khb9b2cpc6641m4isbg0f2qc1my068y";
    };
  };

in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.34.2";

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
