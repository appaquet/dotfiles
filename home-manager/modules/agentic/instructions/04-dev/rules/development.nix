{
  nixantic.sources.development-workflow.instructions."rules/development" =
    { scope }:
    {
      heading = "Development Instructions";
      content = ''

        ## General principles

        * Scope discipline: execute ONLY tasks from approved plan
          * Boy-scout fixes in code already touching fine (small cleanup, typo fix)
          * New tasks, inbox items, discovered issues beyond current scope: inform user, don't act, need plan
          * Mental model: would a dev start this work without team/mgnt agreement?

        * Optimize for future, not minimal diff. Half-measures cost more total effort

        * TODO+TDD-driven:
          * TODOs/stubs -> tests (comment if non-compiling) → implement -> iterate

        * Follow existing patterns, use existing libraries. Don't reinvent.

        * Follow a SR&ED methodology: persist new uncertainties, hypothesis, decisions, insights,
          failed approaches to phase doc

        * Leave existing TODO/FIXME/REVIEW comments intact, unless current work address them

        ${scope.blocks."code-insert-checklist".embed}

        ${scope.blocks."testing-principles".embed}

        ${scope.blocks."development-stop-triggers".embed}

        ${scope.blocks."development-completion-checklist".embed}

        ${scope.blocks."code-commenting".embed}

        ${scope.blocks."error-handling".embed}

        ${scope.blocks."code-organization-order".embed}
      '';
    };
}
