---
name: update-hash
description: Build home and update any missing hash
model: haiku
---

# Update nix hashes

1. Run `./x home build`
2. For any error that a hash is invalid, take the expected hash, update the nix files with the
   expected hash and re-run build.
3. Only stop when all hashes are updated by re-running step 1
