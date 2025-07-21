
# Pull Request / Project documentation

This describes the structure and content of the `PR.md` file that should be created at the root of
the repository and that describe the current task / feature / project that we are working on.

This file is used throughout the development of a new change in the repository. It may contain more
than one pull request if the change is large enough to be split into multiple pull requests.

* Unless requested I requested it, if it doesn't exist, don't create a `PR.md` file on your own. You
  can ask me if you should create one.

* The file should be located at the root of the repository.

* If you need more context, you MUST ask me and add the learned information to the `PR.md` (if it
  exists, at the root of the repo) file so you can refer to it later.

* This file contains these sections (in the exact order):
  * **Context** (mandatory): context of the changes
  * **Requirements** (optional): requirements of the changes
  * **Questions** (optional): as check list, questions (and potential answers) that need to be
    answered throughout the development of the changes
  * **Files** (mandatory): section with modified files OR important files needed for the context of
    the changes..

    * **MANDATORY**: After finishing any request that modifies or useful files, you MUST update this
      section. You must NEVER include generated files (ex: `*.pb.go`, `*.pb.gw.go`, `*_grpc.pb.go`,
      wire generated files, etc.) or PR specific doc files (ex: `PR.md`, feature docs, etc.) in this
      section. Use bullet list format with file paths in bold, followed by a colon and description.
      You should always include files that are crucial to the completion of this task, even if you
      didn't modify them.
    * Format:
      * First 1-2 sentences describing what the file is about and its purpose
      * Next 1-2 sentences describing what changes were made to the file (if any) Only include
        hand-written source files, specifications, and configuration files.
        Example format: `- **path/to/file.go**: Brief description of file purpose. Description of
        changes made.`

  * **TODO** (mandatory): as checkmark list, section with checkmark lists for work items
    * **MANDATORY**: After starting or completing work items, update this section:
      * Format:
        * Incomplete item: `- [ ]`
        * In progress item: `- [~]`
        * Completed item: `- [x]`
      * Mark items as complete when they are fully implemented and working
      * Add new items when you discover additional work needed

  * **Pull requests** (optional): section where description of different pull requests created out of the
    changes are listed
    * **Summary section only**: Start with "In this PR, I implemented..." followed by technical implementation details
    * Focus on what was technically implemented rather than business value
    * Use specific component names and technical terms
    * Keep it concise but technically precise
    * Do NOT include test plans, generated attribution, or other sections
