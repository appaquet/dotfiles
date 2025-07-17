
# Implementation review command

We want to review and fix the comments I've left in the code. I use `// REVIEW:` prefix (adapt to
each language) to mark comments that need to be reviewed and addressed.

1. At the **root of the repository**, use `rg` to search for all comments: `rg -n "// REVIEW:"`
2. Review each comment, there are a few types:
    - Ones that you need to address by fixing the code, implementing a feature, etc.
    - Ones that are used to give you pointers for the other comments or tasks to do.
3. Create an internal TODO list with tasks to be made
4. Address each task one by one, then remove the associated review comments.
5. When you went through all tasks, search again for review comments to make sure you didn't miss any.
6. When you are done, run the configured formatter, lint and tests.
