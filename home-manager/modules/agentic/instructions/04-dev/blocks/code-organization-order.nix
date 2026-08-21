{
  nixantic.sources.development-workflow.blocks."code-organization-order" = {
    heading = "Code organization";

    content = ''
      Before writing any code, always ensure organization follows this order:
    '';

    tag = "code-organization-order";

    taggedContent = ''
      1. Main/Primary: main struct, class, modules
      2. Public before private: APIs before implementation
      3. Dependencies at bottom: Helpers, utilities. Topological order (top-down deps)
    '';
  };
}
