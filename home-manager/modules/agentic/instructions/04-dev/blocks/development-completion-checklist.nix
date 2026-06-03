{
  nixantic.sources.development-workflow.blocks."development-completion-checklist" =
    { scope }:
    {
      heading = "Development completion checklist";

      content = ''
        Before marking the development as completed, ensure to follow this checklist:
      '';

      tag = "development-completion-checklist";

      taggedContent = ''
        * [ ] Initial plan/requirements/ACs/TODOs addressed
        * [ ] Tests are added/updated and passing using ${scope.blocks.testing-principles.reference}
        * [ ] Strictly follow ordering in ${scope.blocks.code-organization-order.reference}
        * [ ] All task ACs verified passing
        * [ ] Changes diff reviewed
        * [ ] Temporary debug files/code removed
        * [ ] Code style guidelines followed
        * [ ] Formatting, linting, type check, tests pass
        * [ ] No unexpected file deletions
        * [ ] Dependent code is still compiling & testing
        * [ ] Project doc updated, if exists
        * [ ] Full project test suite passes
      '';
    };
}
