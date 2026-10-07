{
  # Shared by the implement commands; each prepends its own mode line.
  nixantic.sources.development-workflow.blocks."implement-workflow" =
    { scope }:
    {
      heading = "Implement workflow";

      content = ''
        ## State

        ${scope.blocks."project-files".embed}

        # Instructions

        1. Ensure ${
          scope.skills."project-docs".reference
        } loaded before reading or updating project or phase documents.

        2. Verify 10/10 understanding, if not already done
           * Skip if we just planned and understanding is already in context
           * Read ALL requirements in project doc
           * If unclear, ask user to use ${scope.commands."ctx-improve".reference}
           * Clarify if task contradicts or overlaps

        3. Load tasks from project/phase docs
           * For each task in the plan, set it up for tracking and segment for greater clarity
           * Add validation checks using ${scope.blocks.testing-principles.reference}, grouping related checks. Verification is not a reviewer pass.
           * If user validation needed, task description should be clear about waiting for user input
           * If in orchestrator mode, decide whether each task can be delegated, make the task
             description clear and select the dev agent using ${
               scope.blocks."sub-agent-selection".reference
             }.

        4. Create version control commits for this implementation
           * Check active changes
           * Commit with proper message or change active commit message

        5. Implement tasks
           * Update documentation if existing:
             * Mark phase doc task `[~]` when starting, `[x]` when done
               Like task format dictates. Done = all ACs verified passing
             * Add new tasks discovered to phase doc
             * Note critical decisions
             * Before marking task done: verify each AC sub-item passes
           * If deviating or overcomplicating, STOP and update user
           * If any decisions or discoveries, update project/phase doc
           * Reviewers can be used, but needs to follow ${scope.blocks."reviewer-budget".reference}
           * If an agent is stuck, review the evidence it returned. Resolve the blocker and resume it, or reselect using ${
             scope.blocks."sub-agent-selection".reference
           } when the task needs a different agent

        6. Validate ${scope.blocks."development-completion-checklist".reference}

        7. Validate formatting, linting, tests done

        8. Update project & phase docs using ${scope.commands."proj-save".reference}

        9. Debrief me, following ${scope.blocks."user-briefing".reference}

        ${scope.blocks."engagement-gate".release}
      '';
    };
}
