{
  pkgs,
  config,
  lib,
  inputs',
  ...
}:

let
  instructions = config.nixantic.instructions.rendered;

  mkClaudeConfSymlinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = ".claude/${path}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/agentic/claude/${path}";
        };
      }) paths
    );

  mkClaudeGeneratedSymlinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = ".claude/${path}";
        value = {
          source = "${instructions.package}/claude/${path}";
        };
      }) paths
    );

  claude-code = pkgs.claude-code;

  claude-wrapped = pkgs.writeShellScriptBin "claude" ''
    if [ ! -d ".git" ] && [ ! -d ".jj" ]; then
      echo -e "\e[31mWARNING: No .git or .jj, are you at the root of a project?\e[0m" >&2
      sleep 5
    fi

    # Override claude with overridden config dir. This prevents it from writing its config to
    # ~/.claude.json so that we can keep all claude config in ~/.claude.
    export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.claude"
    export CLAUDE_ROOT="''${CLAUDE_PROJECT_DIR:-$(pwd)}"

    # Enable telemetry and non-essential traffic since some features aren't enabled without
    # https://github.com/numtide/llm-agents.nix/issues/2811
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=""
    export DISABLE_NON_ESSENTIAL_MODEL_CALLS=""
    export DISABLE_TELEMETRY=""

    export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
    export CLAUDE_CODE_NO_FLICKER=1 # alt-mode

    ${claude-code}/bin/claude --verbose "$@"
  '';

  nono-claude = pkgs.writeShellScriptBin "nono-claude" ''
    export HERDR_AGENT=claude
    exec maybe --profile claude -- claude --allow-dangerously-skip-permissions "$@"
  '';

  generatedPaths = [
    "commands"
    "agents"
    "skills"
    "rules"
    "CLAUDE.md"
  ];

  localPaths = [
    "settings.json"
    "docs"
    "statusline.sh"
  ];

in
{
  home.file = (mkClaudeConfSymlinks localPaths) // (mkClaudeGeneratedSymlinks generatedPaths);

  home.packages = [
    claude-wrapped
    nono-claude

    pkgs.socat # required for sandboxing
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.bubblewrap # required for sandboxing
  ];

  dotfiles.nono.profiles.claude = {
    meta.version = "1.0.0";
    extends = "coding-agent";
    groups.include = [ "claude_code_macos" ];
    filesystem = {
      read = [ ];
      allow = [
        "$HOME/.claude"
        "$HOME/.claude.lock"
      ];
      read_file = [ ];
      write_file = [
      ];
    };
    network.block = false;
  };

  programs.fish.shellAbbrs = {
    cc = "claude";
  };
}
