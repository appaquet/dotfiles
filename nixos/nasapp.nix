{
  config,
  pkgs,
  lib,
  ...
}:

let
  nasappIp = "192.168.0.20";

  modOptions = {
    nasapp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NasAPP mounts";
      };

      shares = lib.mkOption {
        type = lib.types.listOf shareType;
        default = [ ];
        description = "List of shares to mount";
      };

      credentials = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Global credentials file for mounting shares";
      };

      uid = lib.mkOption {
        type = lib.types.str;
        default = "appaquet";
        description = "Default UID for mounting shares";
      };

      gid = lib.mkOption {
        type = lib.types.str;
        default = "users";
        description = "Default GID for mounting shares";
      };
    };
  };

  shareType = lib.types.submodule {
    options = {
      share = lib.mkOption {
        type = lib.types.str;
        description = "The share name to mount (no //, only the name)";
      };

      mount = lib.mkOption {
        type = lib.types.str;
        description = "The mount point for the share";
      };

      credentials = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Credentials file override for the share";
      };

      uid = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "UID override for the share";
      };

      gid = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GID override for the share";
      };
    };
  };

  mkMount =
    {
      share,
      credentials,
      uid,
      gid,
    }:
    {
      device = "//${nasappIp}/${share}";
      fsType = "cifs";
      options =
        let
          automount_opts_list = [
            "vers=3.0"
            "uid=${uid}"
            "gid=${gid}"
            # don't mount with fstab, but with systemd & make it resilient to network failures
            # from https://discourse.nixos.org/t/seeking-help-with-mounting-samba-cifs-behind-a-vpn-currently-using-autofs/35436/6
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

  isNullOrEmpty = value: value == null || value == "";

  orDefault = value: default: if isNullOrEmpty value then default else value;
in
{
  options = modOptions;

  config = lib.mkIf config.nasapp.enable {
    environment.systemPackages = [
      pkgs.cifs-utils
    ];

    fileSystems = lib.mkMerge (
      map (shareOpt: {
        "${shareOpt.mount}" = mkMount {
          share = shareOpt.share;
          credentials = orDefault shareOpt.credentials config.nasapp.credentials;
          uid = orDefault shareOpt.uid config.nasapp.uid;
          gid = orDefault shareOpt.gid config.nasapp.gid;
        };
      }) config.nasapp.shares
    );
  };
}
