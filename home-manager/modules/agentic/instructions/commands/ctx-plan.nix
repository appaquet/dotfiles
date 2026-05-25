{ scope }:
{
  description = "Load repository context and create high-level development plans";
  argumentHint = "[task-description]";

  effort = "xhigh";

  content = ''
    Goal: build a full plan for the task at hand: $ARGUMENTS

    Project files: !`claude-proj-docs`
    If no project files, assume we are working in memory only and skip any steps related to project files

    ${scope.forHarness {
      claude = "NEVER engage the native plan mode `EnterPlanMode`";
      default = "";
    }}

    ## Instructions

    1. 🔳 Ensure context loaded - run `ctx-load` skill if not sufficient

    2. 🔳 Ensure task defined - clarify via `AskUserQuestion` if empty or unclear

    3. 🔳 Research and clarify
       - Use sub-agents to explore codebase, find patterns
       - Using the ${scope.blocks.deep-thinking.reference} procedure
       - Search web for unfamiliar concepts if needed
       - For each unknown, add sub-task to investigate
       - Make sure to identity ways to test work as we go
         - If it's non-code or infra, design a way to test (ex: separate harness)
         - If not possible to test, involve user at clear stages to validate work
         - Should be done iteratively, not just at the end as validation step
         - Never run blindly, always inform user if need way to validate
       - List/understand/ask for requirements and acceptance criteria
       - Define ACs per task during planning — each AC is a specific verifiable condition that maps to a test assertion
       - Use `AskUserQuestion` to clarify as you discover uncertainties
       - Persist all planning decisions and investigation outcomes to project/phase doc Questions & Investigations — conversation context is ephemeral

    4. 🔳 Report 10/10 understanding via `full-understanding-checklist`
       - If not 10/10, suggest `/ctx-improve` to improve further more

    5. 🔳 Create development plan
       - Break into logical phases
       - Identify key files and components
       - Develop one component at the time, writing its test before if possible, and make it passes before
         moving on to next step. If user validation needed, add it as a step in the plan
       - Consider dependencies and challenges
       - It is crucial to include testing strategy in plan so you are autonomous

    6. 🔳 Write plan to docs via `proj-editing` skill if we have doc files

    7. **STOP**: User will decide next steps

    ${scope.blocks.pre-flight.reference}
  '';
}
