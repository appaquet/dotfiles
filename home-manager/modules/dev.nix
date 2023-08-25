{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gh

    tokei

    dive # docker container explorer

    protobuf
    capnproto

    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]))
    cloud-sql-proxy
  ];
}

