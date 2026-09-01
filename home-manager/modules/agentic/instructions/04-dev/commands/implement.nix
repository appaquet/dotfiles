{
  nixantic.sources.development-workflow.commands."implement" =
    { scope }:
    {
      description = "Implement tasks from the approved plan";

      arguments = [ { label = "Task"; } ];

      effort = "xhigh";

      content = ''
        Goal: proceed to implementation of the plan/task at hand

        ## State

        ${scope.blocks."project-files".embed}

        # Instructions

        1. Ensure ${
          scope.skills."project-docs".reference
        } loaded before reading or updating project or phase documents.

        2. 🔳 Verify 10/10 understanding, if not already done
           - Skip if we just planned and understanding is already in context
           - Read ALL requirements in project doc
           - If unclear, ask user to use ${scope.commands."ctx-improve".reference}
           - Clarify if task contradicts or overlaps

        3. 🔳 Load tasks from project/phase docs
           - For each task, create 1..n `${scope.harness.tools.taskCreate}`
             - Segment for better tracking
           - Create tasks for verification/testing each implementation step.
           - If user validation needed, task description should be clear about waiting for user input
           - If in orchestrator mode, decide whether each task can be delegated, make the task
             description clear and select the dev agent using ${
               scope.blocks."sub-agent-selection".reference
             }.

        4. Create version control commits for this implementation
           - Check active changes
           - Commit with proper message or change active commit message

        5. 🔳 Implement tasks
           - Follow ${scope.blocks."sub-agents-workflows".reference}
           - Update documentation if existing:
             - Mark phase doc task `[~]` when starting, `[x]` when done
               Like task format dictates. Done = all ACs pass and tested working
             - Add new tasks discovered to phase doc
             - Note critical decisions
             - Before marking task done: verify each AC sub-item passes
           - If deviating or overcomplicating, STOP and update user
           - If any decisions or discoveries, update project/phase doc
           - Review agents can be used on uncertain steps.
             - They are expensive, they should be used mindfully. 
             - Prefer 1-2 review towards then end, and prevent repeated back-and-forth. If that happens, stop, update user.
             - Be very specific on which files @ commits/changes to review
             - Be critical on their findings and focus on real issues. They may be overzealous; let's stick to our plan.
           - If an agent is stuck, review the evidence it returned. Resolve the blocker and resume it, or reselect using ${
             scope.blocks."sub-agent-selection".reference
           } when the task needs a different agent

        6. 🔳 Validate via ${scope.blocks."development-completion-checklist".reference}
           - State each item aloud, confirm compliance

        7. 🔳 Validate formatting, linting, tests done
           - If sub-agents did it, trust them
           - If not, ask them back instead of wasting your context

        8. 🔳 Run ${
          scope.commands."proj-save".reference
        } to update project and phase docs, including version control commits.

        9. 🔳 Debrief me on
           - What you did, learned and deviations from plan
           - Any blockers
           - Expected next steps

        ${scope.blocks."engagement-gate".release}
      '';
    };
}
