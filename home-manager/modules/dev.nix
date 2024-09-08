{ pkgs, lib, ... }:

let
  cargoConfig = "" +
    (if pkgs.stdenv.isLinux then ''
      [target.x86_64-unknown-linux-gnu]
      linker = "clang"
      rustflags = ["-C", "link-arg=-fuse-ld=${pkgs.mold-wrapped}/bin/mold"]
    '' else "");

in
{
  home.packages = (with pkgs; [
    tokei

    dive # docker container explorer
    lazydocker # top like app for docker

    protobuf
    capnproto
    flatbuffers

    gnumake
    bintools # ld, objdump, etc.
  ]) ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
    mold-wrapped
  ]);

  home.file.".cargo/config.toml".text = cargoConfig;
}

