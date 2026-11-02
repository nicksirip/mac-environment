#!/bin/bash
# on-focus-changed guard for ws1.sh. AeroSpace has no "window closed" callback, but
# closing a window changes focus, so this runs on every focus change and re-runs
# ws1.sh only when the number of Ghostty windows differs from the last run
# (ws1.sh writes the count). Every other focus change exits after one cheap query.
A=/opt/homebrew/bin/aerospace   # absolute: exec-and-forget runs with a minimal PATH
STATE="$HOME/.cache/aerospace-ws1.count"

n=$("$A" list-windows --monitor all --app-bundle-id com.mitchellh.ghostty \
      --format '%{window-id}' 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = "$(cat "$STATE" 2>/dev/null)" ] && exit 0
exec "$HOME/.config/aerospace/layouts/ws1.sh"
