{
  nixantic.sources.project-docs.commands."proj-init" = {
    description = "Initialize project folder with project doc and first phase doc";

    argumentHint = "[task-description]";

    content = ''
      Goal: create project folder with project doc and phase doc(s). Not for planning, planning is done separately.

      Task: $ARGUMENTS
      Current date: !`date +%Y/%m/%d`

      ## Instructions

      1. Ensure `proj-editing` skill loaded.

      2. 🔳 Ensure **high level** task description is clear so that we can name it properly
         - If empty, ask user for clarification.
         - If no planning was done, user will call planning, don't infer or ask. Need full plan workflow.

      3. 🔳 Set up project folder
         - Derive name from `jj-current-branch`, confirm with `AskUserQuestion`
         - Create directory per `File Location` in project doc.
         - Create symlink: `ln -s <project-folder> proj`
         - Commit symlink: `jj commit -m "private: proj - <project-name>"`

      4. 🔳 Clarify project details if needed so that we can fill the project squeleton
         - Otherwise, propose user running `/ctx-plan` after

      5. 🔳 Create project doc (00-<name>.md)
         - Follow the project doc rules
         - If next phase clear, create phases section

      6. 🔳 Create phase doc(s) (01-<name>.md, etc.)
         - Follow the phase doc rules
         - Confirm phase name(s) with `AskUserQuestion`
         - Make sure project links to phase
         - Commit docs: `jj commit -m "private: claude: docs - <project-name>"`

      7. **STOP**: User will decide next steps. You can propose, but not via ask.
    '';
  };
}
