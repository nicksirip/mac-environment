#!/bin/bash
# Restore AeroSpace workspace 1:  [ Chrome | Ghostty-A ]
#                                  [        | Ghostty-B ]
# Chrome on the left, two Ghostty windows stacked vertically on the right.
#
# AeroSpace (0.21.x) has no native layout save/restore, so this rebuilds the
# layout from scratch. Window IDs change every relaunch, so windows are looked
# up by bundle id at run time. Top Ghostty = first by window title (sorted), so
# the window order is stable across runs.
#
# Run: service mode -> 1   (alt-shift-; then 1)   or directly from a shell.
# Split sizes are reset to even (balance-sizes) since they can't be captured.
set -u

A=/opt/homebrew/bin/aerospace   # absolute: exec-and-forget runs with a minimal PATH
WS=1

prev=$("$A" list-windows --focused --format '%{window-id}' 2>/dev/null)

chrome=$("$A" list-windows --monitor all --app-bundle-id com.google.Chrome \
           --format '%{window-id}' | head -1)
ghosts=$("$A" list-windows --monitor all --app-bundle-id com.mitchellh.ghostty \
           --format '%{window-title}	%{window-id}' | sort | head -2 | cut -f2)
g1=$(sed -n 1p <<<"$ghosts")
g2=$(sed -n 2p <<<"$ghosts")

if [ -z "$chrome" ] || [ -z "$g1" ] || [ -z "$g2" ]; then
  echo "ws1.sh: need 1 Chrome + 2 Ghostty windows (chrome='$chrome' g1='$g1' g2='$g2')" >&2
  exit 1
fi

# 1. Gather onto workspace 1 and reset its tree to a flat row.
for id in "$chrome" "$g1" "$g2"; do
  "$A" move-node-to-workspace --window-id "$id" "$WS" 2>/dev/null   # no-op notice if already there
done
"$A" workspace "$WS" 2>/dev/null
"$A" flatten-workspace-tree --workspace "$WS"
"$A" layout --workspace "$WS" --root tiles horizontal   # default root is accordion; force tiles (--workspace requires --root)

# 2. Order the row: Chrome | g1 | g2.
#    --boundaries-action stop is REQUIRED: the default (create-implicit-container)
#    wraps the window into a new container when it hits the edge, which nests
#    windows and breaks the layout. With 'stop', an edge move is a true no-op.
mv() { "$A" move --window-id "$1" --boundaries-action stop "$2" 2>/dev/null || true; }
mv "$g2" right; mv "$g2" right          # g2 -> rightmost
mv "$chrome" left; mv "$chrome" left    # chrome -> leftmost (g2 stays last)

# 3. Stack g2 under g1 (opposite-orientation normalization makes the pair vertical).
"$A" join-with --window-id "$g2" left

"$A" balance-sizes

# Return focus to whatever was focused before (if it still exists).
[ -n "$prev" ] && "$A" focus --window-id "$prev" 2>/dev/null || true
