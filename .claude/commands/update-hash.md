---
name: update-hash
description: Build home and update any missing hash
model: haiku
---

# Update nix hashes

1. Run `./x home build 2>&1 | grep -B 5 -A 5 "got:"` to get the hash mismatch error. It's notmal to
   take time, don't use timeout.
2. Look for the line that says `got:    sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=`
3. Copy that hash value and update the corresponding field in the nix file that had the error
4. Repeat steps 1-3 until no more hash errors (usually 1-2 iterations)
5. DONE. Do NOT run additional verification builds.
