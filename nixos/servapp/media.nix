{
  lib,
  ...
}:

{
  # immich
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    mediaLocation = "/data/photos/immich";
    group = "photos";
  };

  # Module defaults to 0077/0700 (owner-only).
  # Override to let photos group members read files on the filesystem
  systemd.services.immich-server.serviceConfig.UMask = lib.mkForce "0027";
  systemd.services.immich-machine-learning.serviceConfig.UMask = lib.mkForce "0027";
  systemd.tmpfiles.settings."immich"."/data/photos/immich".e.mode = lib.mkForce "0750";

  services.postgresqlBackup = {
    enable = true;
    databases = [ "immich" ];
    location = "/data/backup_servapp/postgresql";
    compression = "zstd";
  };

  # jellyfin
  hardware.graphics.enable = true;
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    group = "videos";
  };
  users.users.jellyfin.extraGroups = [
    "render"
    "video"
    "media"
  ];
}
