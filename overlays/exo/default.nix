{ lib, stdenv, fetchurl, system, autoPatchelfHook, rustPlatform, fetchFromGitHub }:

# See https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
rustPlatform.buildRustPackage rec {
  pname = "exo";
  version = "0.1.25";

  src = fetchFromGitHub {
    owner = "appaquet";
    repo = "exocore";
    rev = "68cb916";
    hash = "sha256-dhog4wiYd5v/WJbjch+IgL6iv1fqwEVtvhedQKEubtg=";
  };

  cargoHash = "sha256-dhog4wiYd5v/WJbjch+IgL6iv1fqwEVtvhedQKEubtg";

  meta = {
    description = "Exocore cli";
    homepage = "https://github.com/appaquet/exocore";
    license = lib.licenses.apache20;
    maintainers = [ ];
  };
}
