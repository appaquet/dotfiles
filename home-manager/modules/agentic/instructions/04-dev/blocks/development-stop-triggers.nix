{
  nixantic.sources.development-workflow.blocks."development-stop-triggers" = {
    heading = "When to Stop";
    content = ''
      STEP IMPLEMENTATION as soon as any of these triggers occur:
    '';
    tag = "development-stop-triggers";
    taggedContent = ''
      * Architectural mismatches (mutable vs immutable, incompatible structures)
      * API incompatibilities requiring redesign
      * Multiple failed workarounds
      * No workarounds/reverts/continued coding - ask for help
      * Never claim completion if incomplete
      * Keep executing a command which never succeeds
      * Version control state confusing or operations had unexpected effects
      * Multiple consecutive test failures without progress toward a fix
      * Generating work beyond the planned scope (all tasks complete, inventing new ones)
    '';
  };
}
