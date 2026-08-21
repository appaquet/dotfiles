{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixantic;
  instructionCfg = cfg.instructions;

  sourceType = lib.types.lazyAttrsOf lib.types.raw;
  rulesOutputType = lib.types.enum [
    "files"
    "merge-main"
  ];
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
        description = "Raw nixantic ${kind} sources for this source owner.";
      }
    );
  };

  rendered = import ../framework {
    inherit pkgs lib;
    postProcess = instructionCfg.postProcess;
    bom = instructionCfg.bom;
    sourceRoots = cfg.sourceRoots;
    sources = cfg.sources;
    settings = {
      versionControl = cfg.versionControl;
      harnesses = instructionCfg.harnesses;
    };
  };

  mkWrapper =
    {
      name,
      executable,
      envVar,
      configDir,
    }:
    pkgs.writeShellScriptBin name ''
      export ${envVar}=${lib.escapeShellArg configDir}
      exec ${executable} "$@"
    '';

  wrapperPackages = {
    claude = mkWrapper {
      inherit (instructionCfg.wrappers.claude) name executable;
      envVar = "CLAUDE_CONFIG_DIR";
      configDir = "${rendered.package}/claude";
    };
    opencode = mkWrapper {
      inherit (instructionCfg.wrappers.opencode) name executable;
      envVar = "OPENCODE_CONFIG_DIR";
      configDir = "${rendered.package}/opencode";
    };
  };

  wrapperChecks = {
    claude = pkgs.runCommand "nixantic-claude-wrapper-check" { } ''
      grep -F 'CLAUDE_CONFIG_DIR' ${wrapperPackages.claude}/bin/${instructionCfg.wrappers.claude.name}
      grep -F '${rendered.package}/claude' ${wrapperPackages.claude}/bin/${instructionCfg.wrappers.claude.name}
      touch $out
    '';
    opencode = pkgs.runCommand "nixantic-opencode-wrapper-check" { } ''
      grep -F 'OPENCODE_CONFIG_DIR' ${wrapperPackages.opencode}/bin/${instructionCfg.wrappers.opencode.name}
      grep -F '${rendered.package}/opencode' ${wrapperPackages.opencode}/bin/${instructionCfg.wrappers.opencode.name}
      touch $out
    '';
  };
in
{
  options.nixantic = {
    sourceRoots = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Source-tree roots to discover nixantic source fragments from.";
    };

    sources = lib.mkOption {
      type = lib.types.lazyAttrsOf sourceOwnerType;
      default = { };
      description = "Feature/domain-indexed low-level nixantic sources.";
    };

    versionControl.mode = lib.mkOption {
      type = lib.types.enum [
        "jj"
        "git"
      ];
      default = "jj";
      description = "Version-control mode used when rendering VCS-aware nixantic instruction sources.";
    };

    instructions = {
      postProcess = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply markdown post-processing to generated instruction files.";
      };

      bom = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = "BOM renderer overrides, including encoding metadata.";
      };

      harnesses = {
        claude.rules.output = lib.mkOption {
          type = rulesOutputType;
          default = "files";
          description = "How Claude Code rule instructions are emitted.";
        };

        opencode.rules.output = lib.mkOption {
          type = rulesOutputType;
          default = "files";
          description = "How OpenCode rule instructions are emitted.";
        };

        pi = {
          rules.output = lib.mkOption {
            type = rulesOutputType;
            default = "merge-main";
            description = "How Pi rule instructions are emitted.";
          };
          agents = lib.mkOption {
            type = lib.types.enum [ "tintinweb" ];
            default = "tintinweb";
            description = "Pi sub-agent file adapter expected by the rendered instructions.";
          };
          tasks = lib.mkOption {
            type = lib.types.enum [ "tintinweb" ];
            default = "tintinweb";
            description = "Pi task capability adapter expected by the rendered instructions.";
          };
          questions = lib.mkOption {
            type = lib.types.enum [
              "pi-vault-questionnaire"
              "pi-question-tool"
              "rpiv-ask-user-question"
            ];
            default = "rpiv-ask-user-question";
            description = "Pi question capability adapter expected by the rendered instructions.";
          };
        };
      };

      rendered = lib.mkOption {
        type = lib.types.raw;
        readOnly = true;
        description = "Rendered nixantic package, harness outputs, checks, and block scopes.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Rendered nixantic instruction package.";
      };

      check = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Renderer validation check for the configured instruction framework.";
      };

      wrappers = {
        claude = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "nixantic-claude";
          };
          executable = lib.mkOption {
            type = lib.types.str;
            default = "claude";
          };
        };
        opencode = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "nixantic-opencode";
          };
          executable = lib.mkOption {
            type = lib.types.str;
            default = "opencode";
          };
        };
        packages = lib.mkOption {
          type = lib.types.attrsOf lib.types.package;
          readOnly = true;
          description = "Generic config-dir wrapper packages keyed by harness.";
        };
      };

      wrapperChecks = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        readOnly = true;
        description = "Validation checks for generated wrapper packages.";
      };

    };
  };

  config.nixantic.instructions = {
    inherit rendered wrapperChecks;
    package = rendered.package;
    check = rendered.check;
    wrappers.packages = wrapperPackages;
  };
}
