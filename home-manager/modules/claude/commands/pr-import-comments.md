---
name: pr-import-comments
description: Import unresolved PR review comments as inline code comments with metadata for replies
---

## Step 1: Get PR and Fetch Comments

```bash
# Get current PR number
BRANCH=$(jj-current-branch)
PR_NUMBER=$(gh pr view $BRANCH --json number --jq '.number')

# Fetch unresolved comments
gh api graphql -f query="
{
  repository(owner: \"OWNER\", name: \"REPO\") {
    pullRequest(number: $PR_NUMBER) {
      reviewThreads(first: 50) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes {
              databaseId
              id
              body
              path
              line
              author { login }
              createdAt
              htmlUrl
            }
          }
        }
      }
    }
  }
}" --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .comments.nodes[0]' > unresolved_comments.json
```

## Step 2: Import Comments

For each unresolved comment, add inline comment at the specified line:

**Format:**

```
// REVIEW: pr-import-comments (DB: 1234567890, Node: PRRC_kwABCDEF123456, PR: 1234) - username @ 2025-01-01T12:00:00Z
// URL: https://github.com/OWNER/REPO/pull/1234#discussion_r1234567890
// Location: src/main.rs:42
// First line of comment...
// Second line of comment...
// ... (truncated if longer)
```

**Generate edit commands:**

```bash
jq -r '
  "Edit " + .path + " at line " + (.line | tostring) + ":\n" +
  "// REVIEW: pr-import-comments (DB: " + (.databaseId | tostring) + 
  ", Node: " + .id + ", PR: " + ($PR_NUMBER | tostring) + ") - " + .author.login + " @ " + .createdAt + "\n" +
  "// URL: " + .htmlUrl + "\n" +
  "// Location: " + .path + ":" + (.line | tostring) + "\n" +
  "// " + (.body | split("\n")[0:2] | join("\n// ")) + 
  (if (.body | split("\n") | length) > 2 then "\n// ... (truncated)" else "" end)
' unresolved_comments.json
```

## Step 3: Apply Comments and Cleanup

1. **Apply each edit command** to insert comments at the correct locations
2. **Clean up**: `rm unresolved_comments.json`  
