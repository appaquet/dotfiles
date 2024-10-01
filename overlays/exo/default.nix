{ rustPlatform, fetchFromGitHub }:

# See https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
rustPlatform.buildRustPackage {
  pname = "exo";
  version = "0.1.26";

  src = fetchFromGitHub {
    owner = "appaquet";
    repo = "exocore";
    rev = "v0.1.26";
    hash = "sha256-k+jFQotmH4dfDMMxdOhZZCjYgb5dxB8eOmeDmjUK/0Y=";
  };

  cargoHash = "sha256-p0WMSHNMlbwHfF0bxaXHNRvg6Z+IyyckxrZ3BzMkzgI=";

  cargoBuildFlags = [
    "--package"
    "exo"
  ];

  doCheck = false; # don't run tests

  meta = {
    description = "Exocore cli";
  };
}
