{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v2023.11.3/rtx-v2023.11.3-linux-x64";
      sha256 = "1x88hpisxb327zj28c3cqsl2l1khdghpwdiyv1yr45qss3xy9v0h";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v2023.11.3/rtx-v2023.11.3-macos-arm64";
      sha256 = "0qi6g6njgn32jfg99aq9q92v8vslsrlclbhzyw5shz99lyd8r9g1";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v2023.11.3/rtx-v2023.11.3-macos-x64";
      sha256 = "1mfk0rym63dlkbmzm0yychsc0927rx1ks66dr10zdapsk5dk7g57";
    };
  };

in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v2023.11.3";

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
