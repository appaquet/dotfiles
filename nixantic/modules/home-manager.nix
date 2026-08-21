{ config, lib, ... }:

let
  cfg = config.nixantic;
  instructions = cfg.instructions.rendered;
  harnessNames = instructions.harnessNames;

  installFileType = lib.types.submodule {
    options = {
      harness = lib.mkOption {
        type = lib.types.enum harnessNames;
        description = "Rendered harness output directory to install from.";
      };
      source = lib.mkOption {
        type = lib.types.str;
        description = "Path inside the rendered harness directory.";
      };
      target = lib.mkOption {
        type = lib.types.str;
        description = "Home Manager file target path.";
      };
    };
  };

  describeInstallFile = file: "${file.harness}/${file.source}";
  duplicateTargetMessages =
    let
      byTarget = lib.groupBy (file: file.target) cfg.instructions.install.files;
      conflicting = lib.filterAttrs (_: files: builtins.length files > 1) byTarget;
    in
    lib.mapAttrsToList (
      target: files:
      "target '${target}' mapped by ${builtins.concatStringsSep ", " (map describeInstallFile files)}"
    ) conflicting;

  installFiles =
    assert
      duplicateTargetMessages == [ ]
      || builtins.throw "Duplicate nixantic install.files targets: ${builtins.concatStringsSep "; " duplicateTargetMessages}";
    lib.listToAttrs (
      map (file: {
        name = file.target;
        value.source = "${instructions.package}/${file.harness}/${file.source}";
      }) cfg.instructions.install.files
    );
in
{
  imports = [ ./core.nix ];

  options.nixantic.instructions = {
    install.files = lib.mkOption {
      type = lib.types.listOf installFileType;
      default = [ ];
      description = "Generated instruction files to install into the Home Manager profile.";
    };

    wrappers.install = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the generic Claude Code and OpenCode config-dir wrapper packages into home.packages.";
    };
  };

  config = {
    home.file = installFiles;
    home.packages = lib.optionals cfg.instructions.wrappers.install (
      builtins.attrValues cfg.instructions.wrappers.packages
    );
  };
}
