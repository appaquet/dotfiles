{
  config,
  lib,
  pkgs,
  ...
}:
{
  sops.secrets.caddy.sopsFile = config.sops.secretsFiles.servapp;

  services.caddy = {
    enable = true;

    email = "appaquet@gmail.com";
    logFormat = lib.mkForce "level DEBUG";

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-xRJ5evsAJ2akg47j3Bt6YDXJOgX88B/rKNP50KSVyNY=";
    };
    globalConfig = ''
      acme_dns cloudflare {$CLOUDFLARE_KEY}
    '';
  };

  systemd.services.caddy.serviceConfig = {
    EnvironmentFile = [ config.sops.secrets.caddy.path ];
  };
}
