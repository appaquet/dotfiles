{ rustPlatform, fetchFromGitHub }:

# See https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
rustPlatform.buildRustPackage {
  pname = "exo";
  version = "0.1.25";

  src = fetchFromGitHub {
    owner = "appaquet";
    repo = "exocore";
    rev = "v0.1.26";
    hash = "sha256-SMT5Qal4FkF1MTRDvjWYico6AzH/byqrVUbzpsQiufE=";
  };

  cargoHash = "sha256-mmzDZT/XlLeQPl/Fi+0uf2vcr5G8YA49vUVewFTAels=";

  cargoBuildFlags = [
    "--package"
    "exo"
  ];

  doCheck = false; # don't run tests

  meta = {
    description = "Exocore cli";
  };
}
