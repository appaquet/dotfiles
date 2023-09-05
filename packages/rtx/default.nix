{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v2023.9.0/rtx-v2023.9.0-linux-x64";
      sha256 = "0lbk37g35f729mb98kigg4nv3fb7ljrihlzpszyr9x72vvgxv0ln";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v2023.9.0/rtx-v2023.9.0-macos-arm64";
      sha256 = "0ipjwzsdcb14p7gqral2bsj9p8jckk9sds0w6npwz4hcqjphj9az";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v2023.9.0/rtx-v2023.9.0-macos-x64";
      sha256 = "0ym6zsfc9h7bc9b32pg4fpbffly5ayrphxd5lfcssl86lkspy9sm";
    };
  };

in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v2023.9.0";

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
