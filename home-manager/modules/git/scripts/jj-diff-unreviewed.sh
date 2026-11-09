# Diff the unreviewed stack against its base.
base=$(jj-unreviewed-base)
if [ -z "$base" ]; then
  echo "No unreviewed work on the current line."
  exit 0
fi

jj diff --from "$base" --to @ "$@"
