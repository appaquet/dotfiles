---
name: pr-reply-comments
description: Reply to imported PR review comments and clean up inline comments
---

# PR Reply Comments

## Prerequisites

Must have imported comments using `pr-import-comments` command first.

## Step 1: Find Comments to Reply To

```bash
# List all imported comments with metadata
rg "REVIEW: pr-import-comments \(DB: (\d+), Node: ([^,]+), PR: (\d+)\)" -o --replace='DB: $1, Node: $2, PR: $3'
```

## Step 2: Extract Comment Info and Craft Reply

```bash
# From imported comment, extract:
DATABASE_ID=1234567890    # From "DB: 1234567890"  
PR_NUMBER=1234           # From "PR: 1234"

# Craft reply (must start with robot emoji)
REPLY_BODY="🤖 Generated with Claude 🤖

You're absolutely right about [specific issue].

Here's a fix that addresses this:

\`\`\`rust
// Your code fix here
\`\`\`

This [explanation of why the fix works].

Thanks for catching this!"
```

## Step 3: Send Reply

**CRITICAL**: Use correct endpoint with PR number:

```bash
gh api repos/OWNER/REPO/pulls/${PR_NUMBER}/comments/${DATABASE_ID}/replies \
  -X POST \
  -f body="${REPLY_BODY}"
```

## Step 4: Verify Success and Clean Up

**Verify response includes:**

- ✅ `"in_reply_to_id": 1234567890` (matches your DATABASE_ID)
- ✅ Reply appears in PR conversation thread

**Remove inline comment** after successful reply:

```bash
# Delete the entire comment block:
# // REVIEW: pr-import-comments (DB: 1234567890, Node: PRRC_kwABCDEF123456, PR: 1234) - username @ 2025-01-01T12:00:00Z
# // URL: https://github.com/OWNER/REPO/pull/1234#discussion_r1234567890  
# // Location: src/main.rs:42
# // Comment content...
```

## Troubleshooting

- **404 Error**: Missing PR number in endpoint or wrong DATABASE_ID
- **Not threaded**: Check `"in_reply_to_id"` field in response  
- **New inline comment**: Used wrong endpoint format
