{
  nixantic.sources.main.blocks."context-understanding" =
    { scope }:
    {
      heading = "Context understanding";

      content = ''
        Use the checklist to report understanding before and after improving it. 10/10 means ready for the next planned step, with no unresolved decisions blocking it, not exhaustive knowledge.
        Prioritize web search for tool/library/framework usage since may have changed since cutoff.
      '';

      tag = "full-understanding-checklist";

      taggedContent = ''
        * [ ] Clear on goal/user need: [state the goal]
        * [ ] Understand existing patterns: [describe patterns]
        * [ ] Identified similar use cases: [list them]
        * [ ] Re-read file structure: [list key files]
        * [ ] List existing functions/classes: [name them]
        * [ ] Have test strategy used to iterate: [describe approach]
        * [ ] Know which files to modify: [list files]
        * [ ] Know success criteria / ACs: [state acceptance criteria per task]
        * [ ] Have web searched to ensure fresh decisions: [list search queries and key findings]
      '';
    };
}
