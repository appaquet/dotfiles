{ ... }:
{
  mkMount = { share, credentials, uid?"appaquet", gid?"users" }: {
    device = share;
    fsType = "cifs";
    options =
      let
        automount_opts_list = [
          "uid=${uid}"
          "gid=${gid}"

          # don't mount with fstab, but with systemd & make it resilient to network failures
          # from https://discourse.nixos.org/t/seeking-help-with-mounting-samba-cifs-behind-a-vpn-currently-using-autofs/35436/6
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
}
