
# Implementation review command

We want to review and fix the comments I've left in the code. I use `// REVIEW:` prefix (adapt to
each language) to mark comments that need to be reviewed and addressed.

1. At the **root of the repository**, use `rg` to search for all comments: `rg -n "// REVIEW:"`

   If you can't find any comments, make sure you are indeed at the root of the repository and that
   you aren't limiting by file type.

   If, and only if, you still can't find any comments OR I explicitly asked you, check for comments
   on the pull request itself. Use the proper method to get the current branch via `jj`, then use
   `gh` to get the pull request and its comments. Also make sure you look for draft comments using
   the API or the `gh` command (ex: `gh api repos/someorg/somerepo/pulls/5913/comments`)

2. Review each comment, there are a few types:
    - Ones that you need to address by fixing the code, implementing a feature, etc.
    - Ones that are used to give you pointers for the other comments or tasks to do.
    - Ones that are used to ask questions about the code
    *Don't reply in the code, but directly to me*

3. Create an internal TODO list with tasks to be made. Update `PR.md` to reflect what we need to
   tackle.

4. Address each task one by one, then remove the associated review comments

5. When you went through all tasks, search again for review comments to make sure you didn't miss
   any. Make sure you update the `PR.md` file with the tasks that were completed.

6. When you are done, run tests and then configured formatter and lint, fixing any issues that
   arise.
