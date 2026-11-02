#!/bin/bash
# Restore AeroSpace workspace 1:  [ Chrome | Ghostty column ]
# Chrome on the left; ALL Ghostty windows in one right-hand column:
#   1 Ghostty  -> plain Chrome | Ghostty (enable-normalization-flatten-containers
#                 dissolves one-window containers, so there is no column)
#   2 Ghostty  -> vertical accordion (focused one large, other peeks; alt-j/alt-k)
#   3+ Ghostty -> vertical tiles (accordion would hide non-adjacent windows)
#
# AeroSpace (0.21.x) has no native layout save/restore, so this rebuilds the
# layout from scratch. Window IDs change every relaunch, so windows are looked
# up by bundle id at run time. Ghostty order (top -> bottom) = window title,
# sorted, so the window order is stable across runs.
#
# Run: service mode -> 1   (alt-shift-; then 1)   or directly from a shell.
set -u

A=/opt/homebrew/bin/aerospace   # absolute: exec-and-forget runs with a minimal PATH
WS=1

prev=$("$A" list-windows --focused --format '%{window-id}' 2>/dev/null)

# Single-run lock: on-window-detected and on-focus-changed (ws1-watch.sh) can both
# fire for one event. A lock older than 60 s is treated as stale (killed run).
C="$HOME/.cache"; LOCK="$C/aerospace-ws1.lock"; STATE="$C/aerospace-ws1.count"
mkdir -p "$C"
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null && mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

chrome=$("$A" list-windows --monitor all --app-bundle-id com.google.Chrome \
           --format '%{window-id}' | head -1)
ghosts=()   # bash 3.2 (macOS /bin/bash): no mapfile
while IFS= read -r id; do [ -n "$id" ] && ghosts+=("$id"); done < <(
  "$A" list-windows --monitor all --app-bundle-id com.mitchellh.ghostty \
    --format '%{window-title}	%{window-id}' | sort | cut -f2)
n=${#ghosts[@]}
echo "$n" > "$STATE"   # ws1-watch.sh re-runs this script only when the count changes

if [ -z "$chrome" ] || [ "$n" -eq 0 ]; then
  echo "ws1.sh: need 1 Chrome + at least 1 Ghostty window (chrome='$chrome' ghostty=$n)" >&2
  exit 1
fi

# 1. Gather onto workspace 1 and reset its tree to a flat row.
for id in "$chrome" "${ghosts[@]}"; do
  "$A" move-node-to-workspace --window-id "$id" "$WS" 2>/dev/null   # no-op notice if already there
done
"$A" workspace "$WS" 2>/dev/null
"$A" flatten-workspace-tree --workspace "$WS"
"$A" layout --workspace "$WS" --root tiles horizontal 2>/dev/null   # force a horizontal row (--workspace requires --root); no-op notice if already tiles

# 2. Order the row: Chrome | g1 | g2 | ... | gN.
#    --boundaries-action stop is REQUIRED: the default (create-implicit-container)
#    wraps the window into a new container when it hits the edge, which nests
#    windows and breaks the layout. With 'stop', an edge move is a true no-op.
mv() { "$A" move --window-id "$1" --boundaries-action stop "$2" 2>/dev/null || true; }
push() { local i; for ((i = 0; i <= n; i++)); do mv "$1" "$2"; done; }   # to the edge
for g in "${ghosts[@]}"; do push "$g" right; done   # each goes to the right end -> g1..gN
push "$chrome" left                                  # chrome -> leftmost

# 3. With 2+ Ghostty windows: build the right column, then make it an accordion.
if [ "$n" -ge 2 ]; then
  g1=${ghosts[0]}
  # Pair g2 with g1 (opposite-orientation normalization makes the pair vertical).
  "$A" join-with --window-id "${ghosts[1]}" left
  # g3..gN: moving left enters the column (lands mid-column), then sink to the bottom.
  for ((k = 2; k < n; k++)); do
    mv "${ghosts[k]}" left
    push "${ghosts[k]}" down
  done
  # Exactly 2: vertical accordion (the other window peeks above/below).
  # 3+: vertical tiles. AeroSpace's accordion only shows the focused window's
  # immediate neighbors (layoutAccordion insets every child by accordion-padding),
  # so with 3+ some windows would be fully hidden. Tiles keeps every terminal visible.
  if [ "$n" -eq 2 ]; then
    "$A" layout --window-id "$g1" accordion vertical   # applies to g1's parent: the column
  else
    "$A" layout --window-id "$g1" tiles vertical 2>/dev/null   # no-op notice if already tiles
  fi
fi

"$A" balance-sizes

# Return focus to whatever was focused before (if it still exists).
[ -n "$prev" ] && "$A" focus --window-id "$prev" 2>/dev/null || true
