
# Code Style

## Comments

* Explain "why" not "what" - avoid obvious/redundant
* For complex logic blocks (7+ lines), use delimiter comments for "what"
* Comments describe current state, not evolution - no "now uses", "changed to", "updated to" (that's git history's job)
* Docstrings describe generic capability, not specific use cases - document WHAT it does, not WHY it was created for a particular feature

## No Section Delimiters

Don't mark sections with comments ("// Test Helpers", "// Public Methods", ASCII art). File structure should be self-evident. If markers seem needed, split the file.

## File Organization: Top-Down, Main-to-Dependencies

STRICT ordering. Before modifying: check structure, list functions/structs.

1. **Main/Primary** - Core purpose
2. **Public before private** - APIs before implementation
3. **Dependencies at bottom** - Helpers, utilities
