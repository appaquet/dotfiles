{ config, lib, ... }:

let
  sambaDatasets = lib.filterAttrs (_: ds: ds.samba.enable) config.nas.datasets;

  mkShare =
    name: ds:
    {
      path = "/data/${name}";
      browseable = if ds.samba.browseable then "yes" else "no";
      "read only" = if ds.samba.read_only then "yes" else "no";
      "valid users" = builtins.concatStringsSep " " ds.samba.valid_users;
      "create mask" = ds.samba.create_mask;
      "directory mask" = ds.samba.directory_mask;
    }
    // lib.optionalAttrs (ds.samba.force_group != null) {
      "force group" = ds.samba.force_group;
    };
in
{
  services.samba = {
    enable = true;
    openFirewall = true;

    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "servapp";
        "security" = "user";
        "hosts allow" = "192.168.0. 192.168.1. 100. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest ok" = "no";
        "map to guest" = "never";

        # macOS extended attributes (Finder tags, etc.)
        "ea support" = "yes";
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
      };
    }
    // lib.mapAttrs mkShare sambaDatasets;
  };
}
