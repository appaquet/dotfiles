{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixantic;

  instructions = import ./instructions {
    inherit pkgs lib;
    postProcess = cfg.instructions.postProcess;
    sourceRoots = cfg.sourceRoots;
    sources = cfg.sources;
  };

  sourceType = lib.types.lazyAttrsOf lib.types.raw;
  kinds = [
    "blocks"
    "agents"
    "commands"
    "skills"
    "instructions"
  ];
  sourceOwnerType = lib.types.submodule {
    options = lib.genAttrs kinds (
      kind:
      lib.mkOption {
        type = sourceType;
        default = { };
        description = "Raw nixantic ${kind} sources for this source owner. Values are opaque until evaluated by the instruction renderer.";
      }
    );
  };

  installFileType = lib.types.submodule {
    options = {
      harness = lib.mkOption {
        type = lib.types.enum [
          "claude"
          "opencode"
        ];
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

  installFiles = lib.listToAttrs (
    map (file: {
      name = file.target;
      value.source = "${instructions.package}/${file.harness}/${file.source}";
    }) cfg.instructions.install.files
  );
in
{
  options.nixantic = {
    sourceRoots = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Source-tree roots to discover nixantic source fragments from. Common consumers should prefer this path input; nixantic.sources remains available for generated, test, or advanced low-level declarations.";
    };

    sources = lib.mkOption {
      type = lib.types.lazyAttrsOf sourceOwnerType;
      default = { };
      description = "Feature/domain-indexed low-level nixantic sources. Source owner names are used for authoring provenance and diagnostics only; rendered scope paths remain flat.";
    };

    instructions = {
      postProcess = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply markdown post-processing to generated instruction files.";
      };

      rendered = lib.mkOption {
        type = lib.types.raw;
        readOnly = true;
        description = "Rendered nixantic package, harness outputs, and block scopes.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Rendered nixantic instruction package.";
      };

      install.files = lib.mkOption {
        type = lib.types.listOf installFileType;
        default = [ ];
        description = "Generated instruction files to install into the Home Manager profile.";
      };
    };
  };

  config = {
    nixantic.instructions.rendered = instructions;
    nixantic.instructions.package = instructions.package;

    home.file = installFiles;
  };
}
