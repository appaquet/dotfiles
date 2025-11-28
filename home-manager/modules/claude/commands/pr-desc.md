---
name: pr-desc
description: Generate concise PR description from PR.md file
---

# PR Description

1. Make sure you have `PR.md` (and sub-files if any) loaded for current task.

2. Ensure the "Files" section is up-to-date:
   * Use `jj-diff-branch --stat` to get current branch changes
   * Verify all modified files are documented with proper descriptions
   * Include any crucial unmodified files relevant to the task

3. Create a high-level, concise PR description following the established structure:
   * Start with "In this PR, I implemented..." followed by technical overview
   * Focus on what was technically implemented rather than business value
   * Keep it concise and high-level - answer "what did you build?" not "how does it work?"
   * Use general system/component terms, avoid specific implementation details

4. Write the description to `PR.md` in the "Pull requests" section
