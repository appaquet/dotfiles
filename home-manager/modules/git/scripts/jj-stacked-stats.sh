# Print every change between a starting revision and @, with its stat.
from=${1:-trunk()}
echo "Changes since $from:"

jj --ignore-working-copy log --reversed -r "$from..@" --no-graph -T 'change_id ++ "\n"' |
  while read -r change; do
    jj --ignore-working-copy log -r "$change"
    jj diff --stat -r "$change"
    printf '\n\n'
  done
