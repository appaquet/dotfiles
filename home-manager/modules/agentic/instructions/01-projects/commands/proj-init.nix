{
  nixantic.sources.projects.commands."proj-init" =
    { scope }:
    {
      description = "Initialize project folder with project doc and first phase doc";

      argumentHint = "[task-description]";

      content = ''
        Goal: create project folder with project doc and phase doc(s). Not for planning, planning is done separately.

        Task: $ARGUMENTS
        Current date: !`date +%Y/%m/%d`

        ## State

        ${scope.blocks."current-branch".embed}

        ## Instructions

        1. Ensure ${scope.skills."proj-writing".reference} loaded.

        2. 🔳 Ensure **high level** task description is clear so that we can name it properly
           - If empty, ask user for clarification.
           - If no planning was done, user will call planning, don't infer or ask. Need full plan workflow.

        3. 🔳 Set up project folder
           - Derive name from current branch / change state above, confirm with `AskUserQuestion`
           - Create directory per `File Location` in project doc
           - Create symlink: `ln -s <project-folder> proj`
           - Keep the `proj` symlink isolated in own commit named `private: proj - <project-name>`

        4. 🔳 Clarify project details if needed so that we can fill the project squeleton
           - Otherwise, propose user running ${scope.commands."proj-plan".reference} after

        5. 🔳 Create project doc (00-<name>.md)
           - Follow the project doc rules
           - If next phase clear, create phases section

        6. 🔳 Create phase doc(s) (01-<name>.md, etc.)
           - Follow the phase doc rules
           - Confirm phase name(s) with `AskUserQuestion`
           - Make sure project links to phase
           - Commit docs with message `private: agent: docs - <project-name>`

        7. **STOP**: User will decide next steps. You can propose, but not via ask.
      '';
    };
}
