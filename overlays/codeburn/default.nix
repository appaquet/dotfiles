{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
  nodejs_22,
}:

let
  litellmPrices = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/c23b19f09c5565abd3607eab540e7697a7fe6b2e/model_prices_and_context_window.json";
    hash = "sha256-M8VM0qBnSNeWW2pxBWOhOsoShvx+SlYRH2y64Q+A4cY=";
  };
in
buildNpmPackage rec {
  pname = "codeburn";
  version = "0.9.11";

  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "v${version}";
    hash = "sha256-LbaN2fID/ucYjLebKlknh081hdP+h0VpP5Ex8rV1DUs=";
  };

  nodejs = nodejs_22;

  npmDepsHash = "sha256-Q/z7Pc5Rb1tQ7Fscugb8/qEzxWI2/UCb2OA20N/2Y24=";

  patches = [ ./bundle-litellm.patch ];

  env.LITELLM_PRICES_PATH = toString litellmPrices;

  meta = with lib; {
    description = "See where your AI coding tokens go - by task, tool, model, and project";
    homepage = "https://github.com/getagentseal/codeburn";
    license = licenses.mit;
    mainProgram = "codeburn";
    platforms = platforms.all;
  };
}
