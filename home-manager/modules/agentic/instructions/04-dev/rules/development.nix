{
  nixantic.sources.development-workflow.instructions."development" =
    { scope }:
    {
      role = "rule";
      heading = "Development Instructions";
      content = ''
        ## General principles

        * Scope discipline: execute ONLY tasks from approved plan
          * Boy-scout fixes in code already touching fine (small cleanup, typo fix)
          * New tasks, inbox items, discovered issues beyond current scope: inform user, don't act, need plan
          * Mental model: would a dev start this work without team/mgnt agreement?

        * Development is forward-looking. Prefer the best current and future design over preserving existing or recently added code, behavior, or tests solely for compatibility. Don't preserve code solely because it's still being tested. If it's not used, remove it. If a breaking change is needed, it's better to break it now, but ask for user approval first. After approval, remove or update incompatible code, documentation, and tests. Keep compatibility only when there is a concrete need.

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
