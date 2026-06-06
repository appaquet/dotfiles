{
  nixantic.sources.main.blocks."context-understanding" = {
    heading = "Context understanding";

    content = ''
      Always ensure 10/10 understanding checklist and report it to user, before and after improving it.

      Use explore code + web search + `AskUserQuestion` to fill gaps in understanding until 10/10.

      Prioritize web search for tool/library/framework usage since may have changed since cutoff
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
