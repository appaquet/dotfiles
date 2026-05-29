{
  nixantic.sources.development-workflow.blocks."testing-principles" =
    { scope }:
    {
      heading = "Testing principles";

      content = "";

      tag = "testing-principles";

      taggedContent = ''
        * Philosophy: tests are as important as code and should be as well-crafted. They verify correctness, prevent regressions, and document expected behavior. Good tests enable confident refactoring and maintenance.

        * Assertions: Don't use shallow assertions (present, non-empty, ...): test actual values for potential unforseen changes. Data-changing ops should verify before/after state deltas.

        * Unit vs integration: Unit tests verify isolated logic. Integration tests verify components work together. Both are needed, but integration higher prio. Prefer golden path tests instead of exhaustive edge cases. Test integration seams as bugs cluster at boundaries. Prioritize fakes over mocks, but use real dependencies when feasible.

        * Iterative: create tests first, comment them if needed (non-compiling), then implement code to pass tests. Iterate on both as needed.

        * Failures: when test fails, use ${scope.blocks.problem-solving.reference} to investigate root cause. Don't modify test to make it pass, unless it's genuinely wrong.

        * Browser testing: any modifications to web applications should be tested with browser agent.

        * Infra / environment testing: prioritize external harness to test.

        * User testing: If not possible or hard to test, involve user for manual tests with clear tasks and ACs. Should be a last resort.
      '';
    };
}
