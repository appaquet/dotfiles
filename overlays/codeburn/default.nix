{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
  nodejs_22,
}:

let
  version = "0.9.19";

  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "v${version}";
    hash = "sha256-upA986jO+oeBviitqMhEHf2DgAnZAancmqdqVsY/dEI=";
  };

  litellmPrices = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/8c776605d8c5243c28f852be8f2a481ee025482d/model_prices_and_context_window.json";
    hash = "sha256-urRQYxuGCM4HYa86kLsaoyEYAkDbMaQ2EBKrFZ+ijfw=";
  };

  modelsDevPrices = fetchurl {
    url = "https://raw.githubusercontent.com/symfony/models-dev/596383d71113a4c59f039c6572816976ad41ef10/models-dev.json";
    hash = "sha256-0sO9CZxsi//H6hR9xNby20zokeqMTaMEsMlTRz2bhhc=";
  };

  openRouterPrices = fetchurl {
    url = "https://raw.githubusercontent.com/kj-9/openrouter-models-json/c7a256d242d1f20bb294a3e314afef70f3416fbc/models.json";
    hash = "sha256-TeTIiEJP2j7qyZhWO93TzkqwReuG8noLHQ8XaR2KiHk=";
  };
in
buildNpmPackage rec {
  pname = "codeburn";
  inherit version;

  # https://github.com/getagentseal/codeburn
  inherit src;

  nodejs = nodejs_22;

  npmDepsHash = "sha256-/YTr1x2ka1hUvZPLAlG6Ek5Dw86VosYx3mtFyr5Ardk=";

  patches = [ ./bundle-litellm.patch ];

  # Package the CLI; optional web dashboard assets are intentionally omitted.
  buildPhase = ''
    runHook preBuild
    node scripts/bundle-litellm.mjs
    npm exec --offline -- tsup
    node -e "const fs=require('fs'); fs.copyFileSync('src/cli.ts','dist/cli.js'); fs.chmodSync('dist/cli.js',0o755)"
    runHook postBuild
  '';

  env = {
    LITELLM_PRICES_PATH = toString litellmPrices;
    MODELS_DEV_PATH = toString modelsDevPrices;
    OPENROUTER_MODELS_PATH = toString openRouterPrices;
  };

  meta = with lib; {
    description = "See where your AI coding tokens go - by task, tool, model, and project";
    homepage = "https://github.com/getagentseal/codeburn";
    license = licenses.mit;
    mainProgram = "codeburn";
    platforms = platforms.all;
  };
}
