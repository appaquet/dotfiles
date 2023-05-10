{ pkgs, unstablePkgs, ... }:

{
  imports = [
    ./rust.nix
  ];

  home.packages = with pkgs; [
    nil # nix lsp
    nixpkgs-fmt

    gh

    tokei

    dive # docker container explorer

    protobuf
    capnproto

    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]))
    cloud-sql-proxy
  ];
}
