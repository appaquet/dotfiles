
# Code Style

## Comments

* Doc comments (on struct/function/class/module)
  * Describe WHAT, generically
  * The capability, not specific use cases.
  * Should be skipped when the name and signature already say it
* Inline comments (within bodies)
  * Should explain WHY - non-obvious rationale, constraints, gotchas
  * Skip if obvious
* Comments describe current state, not evolution
  * no "now uses", "changed to", "updated to" (that's git history's job)
  * no references to specific bugs, investigations, function names, types, or error messages —
    describe design intent generically (specifics belong in git history or go stale)
* Don't mark sections with comments. If markers seem needed, split the file
* Test comments: brief behavior labels, not internal mechanics walkthroughs

## Errors

* Error handling is descriptive and actionable
  * In Go, no bare `return nil, err` - always wrap

## Code organization in files

Before writing any code, always ensure organization follows this order:

<file-organization-order>
1. **Main/Primary** - Core purpose
2. **Public before private** - APIs before implementation
3. **Dependencies at bottom** - Helpers, utilities. Topological sort
</file-organization-order>
