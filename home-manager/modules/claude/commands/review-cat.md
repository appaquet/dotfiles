---
name: review-cat
description: Categorize code review findings
---

# Categorize Code Review Findings

1. Call `/review-search` to find all REVIEW comments in the codebase.

2. For each comment found, categorize into priorities and efforts:
    * Priority:
      * High: Critical issues affecting functionality, security, or performance
      * Medium: Important but non-critical improvements
      * Low: Minor suggestions or stylistic changes
    * Effort:
      * Quick Win: Under 15 minutes
      * Moderate: 15-60 minutes
      * Extensive: More than 60 minutes

3. Present categorized findings. **STOP** and wait for instruction on which to address.
