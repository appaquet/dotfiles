{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (google-cloud-sdk.withExtraComponents (
      with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]
    ))
    google-cloud-sql-proxy
  ];
}
