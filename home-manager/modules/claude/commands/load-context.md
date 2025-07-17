
# Load context / project

Load as much context as possible about the project and task at hand.

1. Load and read the relevant repository documentations:
    * README.md
    * ARCHITECTURE.md

2. Read the `PR.md` file at the root of the repository

3. Check if we're on a branch and list all changed files using the fish `jj-stacked-stats` function,
   which will also tell us if we're on a stacked branch

4. Check if we have a PR open for our current branch and other branches part of the stack

5. If it exists, propose next tasks to be done based on the PR.md file
