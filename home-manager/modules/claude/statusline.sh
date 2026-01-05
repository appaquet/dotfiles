#!/usr/bin/env bash
set -euo pipefail

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "?"')

ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
usage=$(echo "$input" | jq -r '.context_window.current_usage // empty')

if [[ -n "$usage" && "$ctx_size" -gt 0 ]]; then
  input_tokens=$(echo "$usage" | jq -r '.input_tokens // 0')
  cache_create=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
  cache_read=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')
  current=$((input_tokens + cache_create + cache_read))
  percent=$((current * 100 / ctx_size))
  ctx="${percent}% ${current}/${ctx_size}"
else
  ctx="0%"
fi

echo "$model │ $ctx"
