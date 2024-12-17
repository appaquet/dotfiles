{
  config,
  pkgs,
  lib,
  ...
}:

let
  mkMount =
    {
      share,
      mount,
      credentials,
      uid,
      gid,
    }:
    {
      device = share;
      fsType = "cifs";
      options =
        let
          automount_opts_list = [
            "uid=${uid}"
            "gid=${gid}"
            "vers=3.0"
            "noauto"
            "x-systemd.automount"
            "x-systemd.idle-timeout=60"
            "x-systemd.device-timeout=5s"
            "x-systemd.mount-timeout=5s"
            "credentials=${credentials}"
          ];
          automount_opts = builtins.concatStringsSep "," automount_opts_list;
        in
        [ automount_opts ];
    };

  shareType = lib.types.attrsOf (
    lib.types.submodule {
      options = {
        share = lib.mkOption {
          type = lib.types.str;
          description = "The share path.";
        };

        mount = lib.mkOption {
          type = lib.types.str;
          description = "The mount point for the share.";
        };

        credentials = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional credentials for the share.";
        };

        uid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional UID for the share.";
        };

        gid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional GID for the share.";
        };
      };
    }
  );
in
{
  options = {
    nasapp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NasAPP mounts.";
      };

      shares = lib.mkOption {
        type = lib.types.listOf shareType;
        default = [ ];
        description = "List of shares to mount.";
      };

      credentials = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Global credential for mounting shares.";
      };

      uid = lib.mkOption {
        type = lib.types.str;
        default = "appaquet";
        description = "Default UID for mounting shares.";
      };

      gid = lib.mkOption {
        type = lib.types.str;
        default = "users";
        description = "Default GID for mounting shares.";
      };
    };
  };

  config = lib.mkIf config.nasapp.enable {
    environment.systemPackages = [
      pkgs.cifs-utils
    ];

    fileSystems = lib.mkMerge (
      # map (shareOpt: {
      #   "${shareOpt.mount}" = mkMount {
      #     share = shareOpt.share;
      #     mount = shareOpt.mount;
      #     credentials = if shareOpt ? credentials then shareOpt.credentials else config.nasapp.credentials;
      #     uid = if shareOpt ? uid then shareOpt.uid else config.nasapp.uid;
      #     gid = if shareOpt ? gid then shareOpt.gid else config.nasapp.gid;
      #   };
      # }) config.nasapp.shares

      map (shareOpt: {
        "bleh" = {
          mountPoint = "${shareOpt.mount}";
          device = "//192.168.0.20/backup_deskapp_vms";
          fsType = "cifs";
        };
      }) config.nasapp.shares
    );
  };
}
