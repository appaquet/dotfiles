# Diff the working copy against the closest bookmark, or trunk when none is reachable.
base=$(jj_diff_base 'closest_bookmark(@)' 'a closest bookmark')
jj diff --from "$base" --to @ "$@"
