---
name: review-plan
description: Research REVIEW comments and present prioritized action plan
---

# Plan Review Comments

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. Call `/review-search` to find all REVIEW comments in the codebase.

2. For each comment found, **research the context**:
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.
   * Read surrounding code to understand the issue
   * Check related files if the change has broader impact
   * Identify dependencies between review items

3. Categorize and prioritize each finding:
   * **Priority**: High (critical/security/functionality), Medium (important but non-critical), Low (minor/stylistic)
   * **Effort**: Quick Win (<15 min), Moderate (15-60 min), Extensive (>60 min)
   * **Dependencies**: Note if items must be addressed in a specific order

4. Present the plan as a prioritized list with research findings.
   **STOP** and wait for instruction on which items to address.
