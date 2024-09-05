{ pkgs, ... }:

{
  home.packages = with pkgs; [
    tokei

    dive # docker container explorer
    lazydocker # top like app for docker

    protobuf
    capnproto
    flatbuffers

    gnumake
    bintools # ld, objdump, etc.
  ];
}

