{
  # The herdr skills join the standalone agent instruction builds, the way hc/default.nix adds them to a home
  # configuration.
  dotfiles.agentic.instructionModules = [ ./skills.nix ];
}
