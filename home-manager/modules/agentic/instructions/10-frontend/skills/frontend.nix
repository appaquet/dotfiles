{
  nixantic.sources.frontend.skills."frontend" = {
    kind = "directory";
    main =
      { scope }:
      {
        description = "Process and validation rules for frontend UI development. Use as soon as creating or modifying UI: HTML, CSS, JS/TS, React, Next.js, templates, components, styles, including one-line spacing or color fixes.";
        content = ''
          # Frontend

          Judge UI by how it renders, not by reading code. Every change affecting rendered UI is validated in the browser via the `chrome` MCP server before it is considered done. Use its browser capabilities (navigate, screenshot, snapshot, evaluate JS, console, network, resize); do not rely on fixed tool names

          ## Workflow
          ### 1. Capture reference (before changing)
          * Open the affected view. Start the dev server if not running, use the project URL
          * Screenshot the affected area: this is the baseline the result must match
          * Extract ground truth of the region being touched via in-page JS: computed padding, margin, gap, font-size, line-height, colors

          ### 2. Change
          * Follow the existing design system: tokens, CSS variables, component patterns, spacing scale. No ad-hoc values where the design already has a scale

          ### 3. Validate (MUST, loop until match)
          After every change, and again before declaring done:
          1. Re-navigate the page and wait until settled. Never act on stale DOM or refs
          2. Structural: page snapshot (correct structure), console messages (no new errors or warnings), network requests (no failed loads)
          3. Visual: screenshot, compare against the captured reference, list the specific discrepancies: spacing, alignment, color, typography, overflow, clipping. Never "looks fine", but perfect.
          4. Fix and repeat from step 1

          ### 4. Quality floor (at completion)
          * Responsive: resize the viewport to mobile (~375px), tablet (~768px), desktop. Screenshot and check each
          * Affected states render: hover, focus, loading, empty, error. Keyboard focus visible
          * No text overflow or clipping, no unexpected horizontal scroll

          ## Pitfalls
          * Screenshot elements for detail, full page for layout context
          * Compare against the captured reference, not memory of it, in the same app state (logged in, data loaded)

          ## Out of scope
          * New-UI design (aesthetics), accessibility and performance audits (WCAG, Lighthouse), framework-specific rules
        '';
      };
    files = { };
  };
}
