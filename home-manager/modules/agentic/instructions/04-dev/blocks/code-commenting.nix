{
  nixantic.sources.development-workflow.blocks."code-commenting" = {
    heading = "Code commenting";

    content = "";

    tag = "code-commenting";

    taggedContent = ''
      * Comments are non-temporal. Describe current state, not evolution
        * Evolution = git history
        * No references to bugs, tickets, investigations, etc.

      * Doc comments (on struct/function/class/module)
        * Non-temporal
        * Describe WHAT they are, not how they evolved
        * 2-3 sentences, should be understanble by juniors

      * Inline comments (within bodies)
        * Should explain WHY - non-obvious rationale, constraints, gotchas
        * Can be used to explain WHAT on non-obvious chunk of code, single line length

      * Test comments: brief behavior labels, not internal mechanics walkthroughs
    '';
  };
}
