{ lib, ... }:
{
  options.nas.datasets = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          vps_backup = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };

          samba = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };

            browseable = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };

            read_only = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };

            valid_users = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };

            force_group = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };

            create_mask = lib.mkOption {
              type = lib.types.str;
              default = "0600";
            };

            directory_mask = lib.mkOption {
              type = lib.types.str;
              default = "0700";
            };
          };
        };
      }
    );
    default = { };
  };
}
