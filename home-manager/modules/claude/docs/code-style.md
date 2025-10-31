
# Code Style

## Comments

* Explain "why" not "what" - avoid obvious/redundant
* For complex logic blocks (7+ lines), use delimiter comments for "what"

## No Section Delimiters

Don't mark sections with comments ("// Test Helpers", "// Public Methods", ASCII art).
File structure should be self-evident. If markers seem needed, split the file.

## File Organization: Top-Down, Main-to-Dependencies

STRICT ordering (never skip "too risky" - do in smaller commits if needed):
Readers understand purpose immediately without reading support code.
Before modifying: check structure, list functions/structs to understand organization.

1. **Main/Primary** - Core classes/messages/functions (file's primary purpose)
2. **Public before private** - Public APIs before implementation details
3. **Dependencies at bottom** - Supporting types, helpers, utilities
