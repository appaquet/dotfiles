
# Load context / project

Load as much context as possible about the project and task at hand.

1. Read the `PR.md` file at the root of the repository. There may be none if we haven't started
   working on a new task yet, but it's fine.

2. Load and read the relevant repository documentations by **looking recursively** for the following
   files using your find method. If you have a `PR.md` with files in it, focus on the relevant
   sections of the repository.
    * README.md
    * ARCHITECTURE.md

3. Check if we're on a branch and list all changed files using the fish `jj-stacked-stats` function,
   which will also tell us if we're on a stacked branch

4. Load the PR from GitHub for the current branch (using `jj-current-branch`), analyse it's
   description and comments. There may be none yet, and it's fine. It is important to get PR for the
   current branch since `gh` won't find one because of detached head.

5. If it exists, propose next tasks to be done based on the PR.md file
