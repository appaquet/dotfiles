{ pkgs, ... }:

{
  humanfirst.enable = true; # enable humanfirst goodies (git shortcuts, jira, etc.)
  humanfirst.identity.email = "app@humanfirst.ai";

  home.packages = with pkgs; [
    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]))
    cloud-sql-proxy
  ];
}
