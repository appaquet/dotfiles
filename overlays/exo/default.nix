{ rustPlatform, fetchFromGitHub }:

# See https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
rustPlatform.buildRustPackage {
  pname = "exo";
  version = "0.1.25";

  src = fetchFromGitHub {
    owner = "appaquet";
    repo = "exocore";
    rev = "bump-deps";
    hash = "sha256-fsDu3ng0oppnsi9hDVkhjHVdOIyYECoTx0wKZg4xfCY=";
  };

  cargoHash = "sha256-p/vX+d2LoGNyU1FiJKjYTpsiuz+2zhdiSLMc8mOJADU=";

  cargoBuildFlags = [
    "--package"
    "exo"
  ];

  doCheck = false; # don't run tests

  meta = {
    description = "Exocore cli";
  };
}
