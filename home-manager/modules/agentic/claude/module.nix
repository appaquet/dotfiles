{
  config,
  pkgs,
  lib,
  inputs',
  ...
}:

let
  cfg = config.dotfiles.claude;
  home = config.home.homeDirectory;

  instructions = config.nixantic.instructions.rendered;
  claude-code = inputs'.llm-agents.packages.claude-code;

  # Instruction artifacts rendered by nixantic.
  generatedPaths = [
    "commands"
    "agents"
    "skills"
    "rules"
    "CLAUDE.md"
  ];

  # Files kept next to this module.
  localPaths = [
    "settings.json"
    "docs"
    "statusline.sh"
  ];

  # Store copy of a local file next to this module, shared by the main and scoped instances.
  mkLocalFileCopy =
    path:
    config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/home-manager/modules/agentic/claude/${path}";

  # home.file entries symlinking the local files above into an instance's config dir.
  mkClaudeConfSymlinks =
    dirName: paths:
    lib.listToAttrs (
      map (path: {
        name = "${dirName}/${path}";
        value = {
          source = mkLocalFileCopy path;
        };
      }) paths
    );

  # home.file entries symlinking the nixantic-rendered instruction artifacts into a config dir.
  mkClaudeGeneratedSymlinks =
    dirName: paths:
    lib.listToAttrs (
      map (path: {
        name = "${dirName}/${path}";
        value = {
          source = "${instructions.package}/claude/${path}";
        };
      }) paths
    );

  # Wrapper script shared by the main and all scoped instances; the config dir is the only difference.
  claudeWrapperScript = configDirName: ''
    if [ ! -d ".git" ] && [ ! -d ".jj" ]; then
      echo -e "\e[31mWARNING: No .git or .jj, are you at the root of a project?\e[0m" >&2
      sleep 5
    fi

    # Override claude with overridden config dir. This prevents it from writing its config to
    # ~/.claude.json so that we can keep all claude config in ~/.claude.
    export CLAUDE_CONFIG_DIR="${home}/${configDirName}"
    export CLAUDE_ROOT="''${CLAUDE_PROJECT_DIR:-$(pwd)}"

    # Enable telemetry and non-essential traffic since some features aren't enabled without
    # https://github.com/numtide/llm-agents.nix/issues/2811
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=""
    export DISABLE_NON_ESSENTIAL_MODEL_CALLS=""
    export DISABLE_TELEMETRY=""

    # Code Mode and agent teams cannot be on in the same session. Code Mode is on; agent teams stay off.
    export CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=0
    export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0

    export CLAUDE_CODE_NO_FLICKER=1 # alt-mode

    ${claude-code}/bin/claude --verbose "$@"
  '';

  # Nono launcher for one instance: runs its wrapper through the instance's sandbox profile.
  nonoLauncherScript =
    { profileName, binName }:
    ''
      exec maybe --profile ${profileName} -- ${binName} --allow-dangerously-skip-permissions "$@"
    '';

  # Nono profile for one instance: sandbox-allow its config dir and the OAuth token-refresh lock
  # dir beside it ($CLAUDE_CONFIG_DIR.lock/); without the lock dir, token refresh silently fails
  # inside the sandbox once the access token expires.
  mkNonoProfile = dirName: {
    meta.version = "1.0.0";
    extends = "coding-agent";
    groups.include = [ "claude_code_macos" ];
    filesystem = {
      read = [ ];
      read_file = [ ];
      write_file = [ ];
      allow = [
        "$HOME/${dirName}"
        "$HOME/${dirName}.lock"
      ];
    };
    network.block = false;
  };

  # Seeds a scope's settings.json from the shared base on first activation only; afterwards the
  # scope owns the file and claude may modify it freely. Runs after linkGeneration since it writes.
  scopeActivation =
    name:
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run mkdir -p "$HOME/.claude-${name}"
      if [ ! -e "$HOME/.claude-${name}/settings.json" ]; then
        run install -m 0644 ${mkLocalFileCopy "settings.json"} "$HOME/.claude-${name}/settings.json"
      fi
    '';
in
{
  # Option: which scopes to provision (AP values live in default.nix).
  options.dotfiles.claude.scopes = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    description = ''
      Scoped Claude Code instances. Each scope name is provisioned with its own config dir
      ~/.claude-<name> (isolated auth, sessions and history), the shared instruction artifacts,
      and a settings.json copied from the shared base on first activation.
    '';
  };

  config = {
    # Config dir entries for the main instance and every scope.
    home.file =
      (mkClaudeConfSymlinks ".claude" localPaths)
      // (mkClaudeGeneratedSymlinks ".claude" generatedPaths)
      // lib.foldl (
        acc: name:
        acc
        // (
          (mkClaudeConfSymlinks ".claude-${name}" (lib.remove "settings.json" localPaths))
          // (mkClaudeGeneratedSymlinks ".claude-${name}" generatedPaths)
        )
      ) { } (lib.attrNames cfg.scopes);

    # Wrapper + nono launcher per instance, plus sandbox dependencies.
    home.packages = [
      (pkgs.writeShellScriptBin "claude" (claudeWrapperScript ".claude"))
      (pkgs.writeShellScriptBin "nono-claude" (nonoLauncherScript {
        profileName = "claude";
        binName = "claude";
      }))

      pkgs.socat # required for sandboxing
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.bubblewrap # required for sandboxing
    ]
    ++ lib.concatMap (name: [
      (pkgs.writeShellScriptBin "claude-${name}" (claudeWrapperScript ".claude-${name}"))
      (pkgs.writeShellScriptBin "nono-claude-${name}" (nonoLauncherScript {
        profileName = "claude-${name}";
        binName = "claude-${name}";
      }))
    ]) (lib.attrNames cfg.scopes);

    # Per-scope first-activation settings.json seed.
    home.activation = lib.mapAttrs' (
      name: _: lib.nameValuePair "claude-scope-${name}" (scopeActivation name)
    ) cfg.scopes;

    # Nono profile per instance.
    dotfiles.nono.profiles =
      lib.mapAttrs' (
        name: _: lib.nameValuePair "claude-${name}" (mkNonoProfile ".claude-${name}")
      ) cfg.scopes
      // {
        claude = mkNonoProfile ".claude";
      };

    # Shell abbr per instance.
    programs.fish.shellAbbrs =
      lib.mapAttrs' (name: _: lib.nameValuePair "cc-${name}" "claude-${name}") cfg.scopes
      // {
        cc = "claude";
      };
  };
}
