{
  nixantic.sources.development-workflow.blocks."testing-principles" =
    { scope }:
    {
      heading = "Testing principles";

      content = "";

      tag = "testing-principles";

      taggedContent = ''
        * Philosophy: tests are as important as code and should be as well-crafted. They verify correctness, prevent regressions, and document expected behavior. Good tests enable confident refactoring and maintenance.

        * Scope: ACs need evidence, not dedicated tests. Existing tests, builds, inspection, or manual checks may cover several ACs.

        * Selection: automate meaningful regression risks in core behavior, non-trivial logic, and important failure paths. Add coverage only where existing checks are insufficient.

        * Maintenance: weigh confidence against test and harness upkeep. Reuse coverage rather than duplicate it across layers. Tests outweighing implementation are a signal to reassess scope, not a fixed line-count limit.

        * Assertions: Don't use shallow assertions (present, non-empty, ...): test actual values for potential unforseen changes. Data-changing ops should verify before/after state deltas.

        * Unit vs integration: test at the layer owning the behavior: integration for risky boundaries, unit for isolated logic. Both aren't required for every change. Prioritize golden paths and consequential failures over exhaustive edge cases. Prefer fakes over mocks, and real dependencies when feasible.

        * Iterative: when new automated coverage is warranted, write tests first, then implement and iterate.

        * Failures: when test fails, use ${scope.blocks.problem-solving.reference} to investigate root cause. Don't modify test to make it pass, unless it's genuinely wrong.

        * Browser testing: any modifications to web applications must be validated in the browser. Use ${
          scope.skills."frontend".reference
        } for any frontend development flow.

        * Infra / environment testing: prefer existing evaluation, build, and smoke checks. Add external harnesses only for uncovered runtime risks.

        * Manual validation: record checks and results; don't substitute for warranted regression coverage. Involve the user when their access or judgment is needed, with clear steps and expected outcomes.
      '';
    };
}
