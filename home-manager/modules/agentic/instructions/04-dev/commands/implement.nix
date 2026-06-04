{
  nixantic.sources.development-workflow.commands."implement" =
    { scope }:
    {
      description = "Implement tasks from the approved plan";

      effort = "xhigh";

      content = ''
        Goal: proceed to implementation of the plan/task at hand

        After instructions & tasks loaded, 🚀 Engage thrusters

        # Instructions

        1. 🔳 Verify 10/10 understanding.
           - Read ALL requirements in project doc
           - If unclear, ask user to `/ctx-improve`
           - Clarify if task contradicts or overlaps

        2. 🔳 Load tasks from project/phase doc/context
           - For each task, create 1..n `${scope.harness.tools.taskCreate}`
             - Segment for better tracking
           - Create tasks for verification/testing each implementation step.
           - If user validation needed, task description should be clear about waiting for user input
           - Think if any task can be delegated to sub-agents, and if so, make sure the task description is clear about the delegation and which sub-agent to select.

        3. Create version control commits for this implementation
           - Check active changes
           - Commit with proper message or change active commit message

        4. 🔳 Implement tasks, using sub-agents delegation
           - You need to follow ${scope.blocks."sub-agents-workflows".reference}
           - Update documentation if existing:
             - Mark phase doc task `[~]` when starting, `[x]` when done
               Like task format dictates. Done = all ACs pass and tested working
             - Add new tasks discovered to phase doc
             - Note critical decisions
             - Before marking task done: verify each AC sub-item passes
           - If deviating or overcomplicating, STOP and update user
           - If any decisions or discoveries, update project/phase doc

        5. 🔳 Validate via `development-completion-checklist`
           - State each item aloud, confirm compliance

        6. 🔳 Validate formatting, linting, tests done
           - If sub-agents did it, trust them
           - If not, ask them back instead of wasting your context

        7. 🔳 Run `proj-save` skill to update project and phase docs

        8. 🔳 If this work is not yet saved, finalize it with the repository version-control workflow. Re-verify repository state first. Changes you don't recognize may be mine.
      '';
    };
}
