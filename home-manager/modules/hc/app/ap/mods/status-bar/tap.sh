#!/bin/sh
# Copied from github.com/PostHog/herdr (claude-usage/mods/claude-usage, rev 489f528). Copyright (c) 2026 PostHog Inc., MIT license: see LICENSE.claude-usage.
# The scope marker is ours: personal and scoped instances share this dump, so each payload records which one
# wrote it, derived from the config directory the statusline runs under.
umask 077
dir="$(cd "$(dirname "$0")/../.." && pwd)/data/claude-usage"
payload="$(cat)"
sid="$(printf '%s' "$payload" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([A-Za-z0-9_-]*\)".*/\1/p' | head -n 1)"
if [ -n "$sid" ]; then
  scope="personal"
  base="${CLAUDE_CONFIG_DIR##*/}"
  case "$base" in
    .claude-*)
      candidate="${base#.claude-}"
      if printf '%s' "$candidate" | grep -qE '^[A-Za-z0-9_-]+$'; then scope="$candidate"; fi
      ;;
  esac
  marked="$payload"
  if ! printf '%s' "$payload" | grep -q '"scope"'; then
    marked="$(printf '%s' "$payload" | sed -E 's/([[:space:]]*\})$/, "scope": "'"$scope"'" \1/')"
  fi
  mkdir -p "$dir/sessions"
  if tmp="$(mktemp "$dir/sessions/.$sid.XXXXXX")"; then
    { printf '%s' "$marked" > "$tmp" && mv -f "$tmp" "$dir/sessions/$sid.json"; } || rm -f "$tmp"
  fi
fi
if [ "$1" = "--tee" ]; then
  printf '%s' "$payload"
  exit
fi
backup="${1:-$dir}"
if [ -s "$backup/original-command" ]; then
  printf '%s' "$payload" | sh -c "$(cat "$backup/original-command")"
fi
