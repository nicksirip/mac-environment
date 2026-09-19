#!/bin/bash
# Joins every pane from the given source window into the current pane's window.
# Usage: join_all_panes.sh <source-window>

source_window="$1"
target_pane=$(tmux display-message -p "#{pane_id}")

tmux list-panes -t "$source_window" -F "#{pane_id}" | while read -r pane; do
  tmux join-pane -s "$pane" -t "$target_pane"
done
