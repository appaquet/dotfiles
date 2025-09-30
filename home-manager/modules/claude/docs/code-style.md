
# General code style guidelines

* Comments should be clear and concise, explaining the "why" rather than the "what". They shouldn't
  be obvious or redundant over the code. Ex:

 ```go
  // Adding user to the database
  db.AddUser(user) // 🛑 bad

  // Since a user may or may not exist yet, we need to use save instead of add and update
  db.SaveUser(user) // ✅ good
  ```

* When the code has a complex chunks of logic that cannot be easily split, it's ok to use comments
  to delimitate and describe the what of that block. It should **ONLY** be used if the block is
  complex and has a minimum of 5 lines.

  Ex:

  ```go
  
  // Handle ABC
  ...
  ...
  ...
  ...
  ...

  // Handle XYZ
  ...
  ...
  ...
  ...
  ...

  ```

* **No section delimiter comments**: Don't use comments to mark sections (e.g., "// Test Helper Functions", "// Public Methods", or ASCII art boxes). Proper code organization and file structure should make sections self-evident. If a file is so large that section markers seem necessary, consider splitting it into multiple files.

* When adding code to a file, always make sure that it's being added to the right place, and that it
  follows the existing code style. I like code to be **top-down, main-to-dependencies**:
  
  **File Organization Principle:**
  * **Main/Primary components first** - the core classes, messages, or functions that represent the primary purpose of the file
  * **Public before private** - within each component, public APIs before private implementation details
  * **Dependencies at the bottom** - supporting types, helper classes, utility functions, or dependency messages that serve the main components
  * **STRICT ordering** - follow the prescribed order without exception. Never skip reorganization because "it's too large" or "too risky". If risky, do it in smaller commits, but get it done.

  This allows readers to understand the main purpose immediately without having to read through supporting code first. IDEs make it easy to jump to definitions when needed.

  **Examples:**
  * **Classes**: Main class first, then helper/dependency classes below
  * **Protobuf**: Primary messages (like `Query`) first, then supporting messages (like `Extension`) below
  * **Functions**: Public API functions first, then private helper functions below
  * **Tests**: All Test* functions first, then test infrastructure, then test helpers

  When you are modifying an existing file, check the structure of the file first and list
  functions/structs if needed before.
