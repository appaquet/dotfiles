let
  main = {
    description = "Editing skill for project doc & its phases";

    content = ''
      Goal: edit project documentations (project & phase docs)

      ## Operations

      1. Create / update Project Doc
        a. Recall project doc structure
        b. Create `00-<name>.md` with all sections
        c. Phases section references first phase doc

      2. Create Phase Doc
        a. Recall phase doc structure
        b. Create `NN-<phase-name>.md`
        c. Context references project doc
        d. All task `[ ]` items go here

      3. Update Task Status
        a. Find task in phase doc
        b. Update: `[ ]` → `[~]` → `[x]`
        c. If all done, ask user if want to complete phase

      4. Update Phase Status
        a. In project doc Phases section
        b. Update: `⬜` → `🔄` → `✅` (if user decides)

      5. Validate Structure
        a. Check project doc follows structure
        b. Check phase docs follows structure
        c. Verify no task items in project doc
        d. Verify all phases have phase docs & linked
        e. Update checkpoint with just-completed & next steps
    '';
  };
in
{
  nixantic.sources.project-docs.skills."proj-editing" = {
    kind = "directory";
    inherit main;
    files = { };
  };
}
