{ pkgs, unstablePkgs, lib, secrets, ... }:

let
  # Set mold as linker
  # Disable readonly segment in mold for `perf` (See https://github.com/flamegraph-rs/flamegraph)
  cargoConfig = "" +
    (if pkgs.stdenv.isLinux then ''
      [target.x86_64-unknown-linux-gnu]
      linker = "clang"
      rustflags = ["-Clink-arg=-fuse-ld=${pkgs.mold-wrapped}/bin/mold", "-Clink-arg=-Wl,--no-rosegment"]
    '' else "");

in
{
  imports = [
    secrets.devHome
  ];

  home.packages = (with pkgs; [
    tokei

    dive # docker container explorer
    lazydocker # top like app for docker

    protobuf
    capnproto
    flatbuffers

    gnumake
    bintools # ld, objdump, etc.
  ]) ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.mold-wrapped
    unstablePkgs.binsider # binary analysis tool
  ];

  home.file.".cargo/config.toml".text = cargoConfig;
}

