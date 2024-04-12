{ pkgs, unstablePkgs, ... }:

{
  home.packages = with pkgs; [
    gh

    tokei

    dive       # docker container explorer
    lazydocker # top like app for docker

    protobuf
    capnproto
    flatbuffers

    unstablePkgs.mold-wrapped # 23.11 still points to old 2.3.3 which had bug

    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]))
    google-cloud-sql-proxy
  ];
}

