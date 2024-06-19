{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gh

    tokei

    dive # docker container explorer
    lazydocker # top like app for docker

    protobuf
    capnproto
    flatbuffers

    mold-wrapped

    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]))
    google-cloud-sql-proxy
  ];
}

