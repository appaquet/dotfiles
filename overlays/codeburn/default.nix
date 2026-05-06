{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
  nodejs_22,
}:

let
  litellmPrices = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/108b87fb246ff5da4d216b9fd2b862c3378590f8/model_prices_and_context_window.json";
    hash = "sha256-ERS+6lQgDUXCsqEonUQq9L+aNDgzYV5LNvlQ7ueizqc=";
  };
in
buildNpmPackage rec {
  pname = "codeburn";
  version = "0.9.6";

  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "v${version}";
    hash = "sha256-bDBOqwv0U08XDlsmaHeu2/X6Z7S1txei93fVD3oI9kE=";
  };

  nodejs = nodejs_22;

  npmDepsHash = "sha256-LNVzrP4F7JAhseo2ApXIvvl1vdbrVntrTlzsaEAhGDc=";

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
