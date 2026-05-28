{
  nixantic.sources.root-instructions.blocks."context-understanding" =
    { scope }:
    {
      heading = "Context understanding";

      content = ''
        Always ensure 10/10 understanding checklist: explore code + web search + `AskUserQuestion`

        Prioritize web search for tool/library/framework usage since may have changed since cutoff

        Always report on understanding at any decision point - verbalize WHAT you understand for each item, not just that you checked it. User validates your understanding.
      '';

      tag = "full-understanding-checklist";

      taggedContent = ''
        * [ ] Clear on goal/user need: [state the goal]
        * [ ] Identified similar use cases: [list them]
        * [ ] Understand existing patterns: [describe patterns]
        * [ ] Re-read file structure: [list key files]
        * [ ] List existing functions/classes: [name them]
        * [ ] Have test strategy used to iterate: [describe approach]
        * [ ] Know which files to modify: [list files]
        * [ ] Know success criteria / ACs: [state acceptance criteria per task]
        * [ ] Have web searched to ensure fresh decisions: [list search queries and key findings]
      '';
    };
}
