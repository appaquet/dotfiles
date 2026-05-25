{ scope }:
{
  heading = "Testing principles";

  content = "";

  tag = "testing-principles";

  taggedContent = ''
    * Tests must verify outcomes (state changes, return values), not just that code runs without error.
      A test that only checks "no exception thrown" is incomplete — assert expected state
    * For data-changing operations, verify before/after state deltas
    * Unit tests verify isolated logic. Integration tests verify components work together.
      Both are needed — passing unit tests alone does not guarantee the system works end-to-end
    * Test at least one cross-feature interaction or integration seam per feature. Bugs cluster
      at boundaries between components
    * Never modify an existing test to make it pass — fix the code. If the test is genuinely wrong,
      explain why before changing it
    * Never write helper scripts that bypass the actual system under test
    * Include at least one test with intentionally invalid input to verify error handling rejects it
    * After writing tests, ask: would these tests catch the bug if the implementation were subtly
      wrong? Tests that mirror the implementation's assumptions don't add safety
  '';
}
