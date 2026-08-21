{
  nixantic.sources.development-workflow.blocks."code-commenting" = {
    heading = "Code commenting";

    content = "";

    tag = "code-commenting";

    taggedContent = ''
      * Comments are non-temporal. Describe current state, not evolution
        * git history is the source of truth for evolution, not comments
        * no references to bugs, tickets, investigations, etc.

      * Doc comments (on struct/function/class/module)
        * Non-temporal
        * Describe WHAT. 
        * Capability, not specific use cases
        * Skipped when not adding value when code simple

      * Inline comments (within bodies)
        * Skip if obvious
        * Should explain WHY - non-obvious rationale, constraints, gotchas

      * Don't mark sections with comments. If markers seem needed, split the file

      * Test comments: brief behavior labels, not internal mechanics walkthroughs
    '';
  };
}
