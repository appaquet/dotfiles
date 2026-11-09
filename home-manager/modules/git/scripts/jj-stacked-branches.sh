# Print the bookmarks between trunk and the working copy, oldest first.
jj --ignore-working-copy log --no-graph \
  -r '(trunk()..@ | trunk()) & bookmarks()' \
  -T 'local_bookmarks.map(|b| b.name()).join(",") ++ "\n"'
