# Diff the working copy against the previous bookmark in the stack, or trunk.
previous=$(jj --ignore-working-copy log --no-graph \
  -r '(trunk()..@ | trunk()) & bookmarks()' \
  -T 'commit_id ++ "\n"' | jj_second_or_only_line)

base=$(jj_diff_base "$previous" 'the previous stacked bookmark')
jj diff --from "$base" --to @ "$@"
