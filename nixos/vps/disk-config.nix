{ ... }:
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "main-boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "main-ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "main-root";
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              passwordFile = "/tmp/secret.key";
              settings.allowDiscards = true;
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };

    disk.data = {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "datapool";
            };
          };
        };
      };
    };

    zpool.datapool = {
      type = "zpool";
      options.ashift = "12";
      rootFsOptions = {
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        keylocation = "prompt";
        canmount = "off";
        mountpoint = "none";
      };

      datasets.data = {
        type = "zfs_fs";
        options = {
          mountpoint = "/data";
          canmount = "on";
        };
      };
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };
        };
      };
    };
  };
}
