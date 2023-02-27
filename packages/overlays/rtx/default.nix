{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, pkg-config
, libiconv
, openssl
, breakpointHook
, darwin ? null
}:

rustPlatform.buildRustPackage rec {
  pname = "rtx";
  version = "v1.18.0";

  src = fetchFromGitHub {
    owner = "jdxcode";
    repo = "rtx";
    rev = "3c979d9564147bb0ef3d7748daa32f2899542ca6";
    sha256 = "cw35KMMEGOWI2vYAfv5B7BPMJf1VXTbkKDbcx6mcrgw=";
  };

  cargoSha256 = "pUCKCQFsHlOsCMrj6Z48r4eX5UfhTtEdRb8m8Es8BF8=";
  cargoPatches = [ ./0001-no-vendored-openssl.patch ];

  nativeBuildInputs = [
    # breakpointHook
    pkg-config
  ];

  buildInputs = [ openssl ] ++ lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [ Security ]);

  meta = with lib; {
    description = "Runtime Executor (asdf rust clone) ";
    homepage = "https://github.com/jdxcode/rtx";
    license = licenses.mit;
  };
}
